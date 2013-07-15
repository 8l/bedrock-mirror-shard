Require Import Ascii Bool String List.
Require Import ExtLib.Tactics.Consider. 
Require Import Word Memory SepExpr SymEval SepIL Env Prover SymEval IL SymIL ILEnv.
Require Import sep.Array.
Require Import Allocated.
Require Import ListFacts.
Require Import Arrays.

Require Import MirrorShard.Expr.


Set Implicit Arguments.

Definition vals := string -> W.

Definition toArray (ns : list string) (vs : vals) : list W := map vs ns.

Definition locals (ns : list string) (vs : vals) (avail : nat) (p : W) : HProp :=
  ([| NoDup ns |] * array (toArray ns vs) p * ((p ^+ $(length ns * 4)) =?> avail))%Sep.

Definition ascii_eq (a1 a2 : ascii) : bool :=
  let (b1, c1, d1, e1, f1, g1, h1, i1) := a1 in
  let (b2, c2, d2, e2, f2, g2, h2, i2) := a2 in
    eqb b1 b2 && eqb c1 c2 && eqb d1 d2 && eqb e1 e2
    && eqb f1 f2 && eqb g1 g2 && eqb h1 h2 && eqb i1 i2.

Lemma ascii_eq_true : forall a,
  ascii_eq a a = true.
Proof.
  destruct a; simpl; intuition.
  repeat rewrite eqb_reflx; reflexivity.
Qed.

Lemma ascii_eq_false : forall a b,
  a <> b -> ascii_eq a b = false.
  destruct b, a; simpl; intuition.
  match goal with
    | [ |- ?E = _ ] => case_eq E
  end; intuition.
    repeat match goal with
             | [ H : _ |- _ ] => apply andb_prop in H; destruct H
             | [ H : _ |- _ ] => apply eqb_prop in H
           end; congruence.
Qed.

Fixpoint string_eq (s1 s2 : string) : bool :=
  match s1, s2 with
    | EmptyString, EmptyString => true
    | String a1 s1', String a2 s2' => ascii_eq a1 a2 && string_eq s1' s2'
    | _, _ => false
  end.

Theorem string_eq_true : forall s,  string_eq s s = true.
Proof.
  induction s; simpl; intuition; rewrite ascii_eq_true; assumption.
Qed.

Theorem string_eq_false : forall s1 s2,
  s1 <> s2 -> string_eq s1 s2 = false.
  induction s1; destruct s2; simpl; intuition.
  match goal with
    | [ |- ?E = _ ] => case_eq E
  end; intuition.
  repeat match goal with
           | [ H : _ |- _ ] => apply andb_prop in H; destruct H
           | [ H : _ |- _ ] => apply eqb_prop in H
         end.
  destruct (ascii_dec a a0); subst.
  destruct (string_dec s1 s2); subst.
  tauto.
  apply IHs1 in n; congruence.
  apply ascii_eq_false in n; congruence.
Qed.

Theorem string_eq_correct : forall s1 s2,
  string_eq s1 s2 = true -> s1 = s2.
Proof.
  intros; destruct (string_dec s1 s2); subst; auto.
  apply string_eq_false in n; congruence.
Qed.

Definition sel (vs : vals) (nm : string) : W := vs nm.
Definition upd (vs : vals) (nm : string) (v : W) : vals := fun nm' =>
  if string_eq nm' nm then v else vs nm'.

Theorem ascii_eq_correct : forall a b, ascii_eq a b = true -> a = b.
Proof.
  intros.
  destruct a. destruct b.
  simpl in H.
  repeat match goal with 
           | _ : context [ eqb ?A ?B ] |- _ =>
             consider (Bool.eqb A B); intros; [ subst; simpl in * | discriminate ]
         end.
  eapply eqb_prop in H0. subst.
  reflexivity.
Qed.

Definition bedrock_type_ascii : type :=
  {| Impl := ascii
   ; Eqb := ascii_eq
   ; Eqb_correct := ascii_eq_correct |}.

Definition bedrock_type_string : type :=
  {| Impl := string
   ; Eqb := string_eq
   ; Eqb_correct := string_eq_correct |}.

Definition bedrock_type_listString : type :=
  {| Impl := list string
   ; Eqb := (fun _ _ => false)
   ; Eqb_correct := @ILEnv.all_false_compare _ |}.

Definition bedrock_type_vals : type :=
  {| Impl := vals
   ; Eqb := (fun _ _ => false)
   ; Eqb_correct := @ILEnv.all_false_compare _ |}.

Definition types_r : Env.Repr type :=
  Eval cbv beta iota zeta delta [ Env.listOptToRepr ] in 
    let lst := 
      (@Some type ILEnv.bedrock_type_W) ::
      (@Some type ILEnv.bedrock_type_setting_X_state) ::
      None ::
      None ::
      (@Some type ILEnv.bedrock_type_nat) ::
      None ::
      (@Some type ILEnv.bedrock_type_bool) ::
      (@Some type bedrock_type_ascii) ::
      (@Some type bedrock_type_string) ::
      (@Some type bedrock_type_listString) ::
      (@Some type bedrock_type_vals) ::
      nil
    in Env.listOptToRepr lst EmptySet_type.

Local Notation "'pcT'" := (tvType 0).
Local Notation "'stT'" := (tvType 1).
Local Notation "'wordT'" := (tvType 0).
Local Notation "'natT'" := (tvType 4).
Local Notation "'boolT'" := (tvType 6).
Local Notation "'asciiT'" := (tvType 7).
Local Notation "'stringT'" := (tvType 8).
Local Notation "'listStringT'" := (tvType 9).
Local Notation "'valsT'" := (tvType 10).

Definition badLocalVariable := O.
Global Opaque badLocalVariable.

Fixpoint variablePosition (ns : list string) (nm : string) : nat :=
  match ns with
    | nil => badLocalVariable
    | nm' :: ns' => if string_dec nm' nm then O
      else 4 + variablePosition ns' nm
  end.

Local Notation "'wplusF'" := 0.
Local Notation "'wmultF'" := 2.
Local Notation "'natToWF'" := 5.
Local Notation "'trueF'" := 11.
Local Notation "'falseF'" := 12.
Local Notation "'AsciiF'" := 13.
Local Notation "'EmptyStringF'" := 14.
Local Notation "'StringF'" := 15.
Local Notation "'nilF'" := 16.
Local Notation "'consF'" := 17.
Local Notation "'selF'" := 18.
Local Notation "'updF'" := 19.
Local Notation "'InF'" := 20.
Local Notation "'variablePositionF'" := 21.

Section parametric.
  Variable types' : list type.
  Definition types := repr types_r types'.
  Variable Prover : ProverT.

  Definition true_r : signature types.
    refine {| Domain := nil; Range := boolT |}.
    exact true.
  Defined.

  Definition false_r : signature types.
    refine {| Domain := nil; Range := boolT |}.
    exact false.
  Defined.

  Definition Ascii_r : signature types.
    refine {| Domain := boolT :: boolT :: boolT :: boolT :: boolT :: boolT :: boolT :: boolT :: nil; Range :=  asciiT |}.
    exact Ascii.
  Defined.

  Definition EmptyString_r : signature types.
    refine {| Domain := nil; Range := stringT |}.
    exact EmptyString.
  Defined.

  Definition String_r : signature types.
    refine {| Domain := asciiT :: stringT :: nil; Range := stringT |}.
    exact String.
  Defined.

  Definition nil_r : signature types.
    refine {| Domain := nil; Range := listStringT |}.
    exact (@nil _).
  Defined.

  Definition cons_r : signature types.
    refine {| Domain := stringT :: listStringT :: nil; Range := listStringT |}.
    exact (@cons _).
  Defined.

  Definition sel_r : signature types.
    refine {| Domain := valsT :: stringT :: nil; Range := wordT |}.
    exact sel.
  Defined.

  Definition upd_r : signature types.
    refine {| Domain := valsT :: stringT :: wordT :: nil; Range := valsT |}.
    exact upd.
  Defined.

  Definition In_r : signature types.
    refine {| Domain := stringT :: listStringT :: nil; Range := tvProp |}.
    exact (@In _).
  Defined.

  Definition variablePosition_r : signature types.
    refine {| Domain := listStringT :: stringT :: nil; Range := natT |}.
    exact variablePosition.
  Defined.

  Definition funcs_r : Env.Repr (signature types) :=
    Eval cbv beta iota zeta delta [ Env.listOptToRepr ] in 
      let lst := 
        Some (ILEnv.wplus_r types) ::
        None ::
        Some (ILEnv.wmult_r types) ::
        None ::
        None ::
        Some (ILEnv.natToW_r types) ::
        Some (ILEnv.O_r types) ::
        Some (ILEnv.S_r types) ::
        None ::
        None ::
        None ::
        Some true_r ::
        Some false_r ::
        Some Ascii_r ::
        Some EmptyString_r ::
        Some String_r :: 
        Some nil_r ::
        Some cons_r ::
        Some sel_r ::
        Some upd_r ::
        Some In_r ::
        Some variablePosition_r ::
        nil
      in Env.listOptToRepr lst (Default_signature _).

  Section toConsts.
    Variable funcs' : functions types.
    Let funcs := repr funcs_r funcs'.

    Definition toConst_bool (e : expr) : option bool :=
      match e with
        | Func trueF nil => Some true
        | Func falseF nil => Some false
        | _ => None
      end.

    Definition toExpr_bool (b : bool) : expr :=
      match b with
        | true => Func trueF nil
        | false => Func falseF nil
      end.

    Theorem toConst_bool_sound : forall e,
                                   match toConst_bool e with
                                     | Some b => forall uvars vars, exprD funcs uvars vars e boolT = Some b
                                     | None => True
                                   end.
    Proof.
      destruct e; simpl; auto.
      repeat ((destruct f; auto; [ ])).
      destruct f. destruct l; reflexivity.
      destruct f. destruct l; reflexivity.
      auto.
    Qed.

    Theorem toExpr_bool_sound : forall b us vs, 
                                  exprD funcs us vs (toExpr_bool b) boolT = Some b.
    Proof.
      destruct b; reflexivity.
    Qed.

    Definition toConst_ascii (e : expr) : option ascii :=
      match e with
        | Func AsciiF (a :: b :: c :: d :: e :: f :: g :: h :: nil) =>
          match toConst_bool a , toConst_bool b , toConst_bool c , toConst_bool d , 
                toConst_bool e , toConst_bool f , toConst_bool g , toConst_bool h with
            | Some a , Some b , Some c , Some d , Some e , Some f , Some g , Some h =>
              Some (Ascii a b c d e f g h)
            | _ , _ , _ , _ , _ , _ , _ , _ => None
          end
        | _ => None
      end.

    Definition toExpr_ascii (a : ascii) : expr :=
      match a with
        | Ascii a b c d e f g h =>
          Func AsciiF (toExpr_bool a :: toExpr_bool b :: toExpr_bool c :: toExpr_bool d ::
                       toExpr_bool e :: toExpr_bool f :: toExpr_bool g :: toExpr_bool h :: nil)
      end.

    Theorem toExpr_ascii_sound : forall a us vs, 
                                  exprD funcs us vs (toExpr_ascii a) asciiT = Some a.
    Proof.
      destruct a; simpl; intros. repeat rewrite toExpr_bool_sound. reflexivity.
    Qed.

    Theorem toConst_ascii_sound : forall e,
                                   match toConst_ascii e with
                                     | Some b => forall uvars vars, exprD funcs uvars vars e asciiT = Some b
                                     | None => True
                                   end.
    Proof.
      destruct e; simpl; auto.
      repeat ((destruct f; auto; [ ])).
      repeat ((destruct l; auto; [ ])).
      simpl.
      repeat match goal with
               | H : _ |- _ => 
                 rewrite H; clear H
               | |- context [ toConst_bool ?e ] =>
                 generalize (@toConst_bool_sound e); destruct (toConst_bool e); intros; auto
             end.
      reflexivity.
    Qed.

    Fixpoint toConst_string (e : expr) : option string :=
      match e with
        | Func EmptyStringF nil => Some EmptyString
        | Func StringF (s :: ss :: nil) =>
          match toConst_ascii s , toConst_string ss with
            | Some s , Some ss => Some (String s ss)
            | _ , _ => None
            end
        | _ => None
      end.

    Fixpoint toExpr_string (s : string) : expr :=
      match s with
        | EmptyString => Func EmptyStringF nil
        | String s ss => Func StringF (toExpr_ascii s :: toExpr_string ss :: nil)
      end.

    Theorem toConst_string_sound : forall e,
                                   match toConst_string e with
                                     | Some b => forall uvars vars, exprD funcs uvars vars e stringT = Some b
                                     | None => True
                                   end.
    Proof.
      induction e; simpl; auto.
      repeat ((destruct f; auto; [ ])).
      destruct f. destruct l; auto.
      destruct f; auto.      
      repeat ((destruct l; auto; [ ])).
      generalize (toConst_ascii_sound e). destruct (toConst_ascii e); intros; auto.
      inversion H; clear H; subst.
      inversion H4; clear H4; subst.      
      destruct (toConst_string e0); intros; auto. 
      simpl. rewrite H0. rewrite H2. reflexivity.
    Qed.

    Theorem toExpr_string_sound : forall s us vs, 
                                  exprD funcs us vs (toExpr_string s) stringT = Some s.
    Proof.
      induction s; simpl; intros. reflexivity. rewrite toExpr_ascii_sound. rewrite IHs. reflexivity.
    Qed.

  End toConsts.

  Inductive deref_res :=
  | Nothing : deref_res
  | Constant : expr -> nat -> deref_res
  | Symbolic : expr -> expr -> expr -> deref_res.
  (* Last one's args: base, variable list, and specific variable name *)

  Definition deref (e : expr) : deref_res :=
    match e with
      | Func wplusF (base :: offset :: nil) =>
        match offset with
          | Func natToWF (k :: nil) =>
            match toConst_nat k with
              | None => 
                match k with 
                  | Func variablePositionF (xs :: x :: nil) => Symbolic base xs x
                  | _ => Nothing
                end
              | Some k =>
                match div4 k with
                  | None => Nothing
                  | Some k' => Constant base k'
                end
            end
          | _ => Nothing
        end

      | _ => Nothing
    end.

  Fixpoint listIn (e : expr) : option (list string) :=
    match e with
      | Func nilF nil => Some nil
      | Func consF (s :: t :: nil) =>
        match toConst_string s with
          | Some s =>  match listIn t with
                         | None => None
                         | Some t => Some (s :: t)
                       end
          | _ => None
        end 
      | _ => None
    end.

  Fixpoint sym_sel (vs : expr) (nm : string) : expr :=
    match vs with
      | Func updF (vs' :: nm' :: v :: nil) =>
        match toConst_string nm' with
          | Some nm' =>
            if string_eq nm' nm
              then v
              else sym_sel vs' nm
          | None => Func selF (vs :: toExpr_string nm :: nil)
        end
      | _ => Func selF (vs :: toExpr_string nm :: nil)
    end.

  Definition sym_read (summ : Prover.(Facts)) (args : list (expr)) (p : expr)
    : option (expr) :=
    match args with
      | ns :: vs :: _ :: p' :: nil =>
        match deref p with
          | Nothing => None
          | Constant base offset =>
            match listIn ns with
              | None => None
              | Some ns' =>
                if Prover.(Prove) summ (Equal wordT p' base)
                  then match nth_error ns' offset with
                         | None => None
                         | Some nm => Some (sym_sel vs nm)
                       end
                  else None
            end
          | Symbolic base nms nm =>
            if Prover.(Prove) summ (Equal wordT p' base)
              && Prover.(Prove) summ (Equal listStringT nms ns)
              && Prover.(Prove) summ (Func InF (nm :: nms :: nil))
              then Some (Func selF (vs :: nm :: nil))
              else None
        end
      | _ => None
    end.

  Definition sym_write (summ : Prover.(Facts)) (args : list expr) (p v : expr)
    : option (list (expr)) :=
    match args with
      | ns :: vs :: avail :: p' :: nil =>
        match deref p with
          | Nothing => None
          | Constant base offset =>
            match listIn ns with
              | None => None
              | Some ns' =>
                if Prover.(Prove) summ (Equal wordT p' base)
                  then match nth_error ns' offset with
                         | None => None
                         | Some nm => Some (ns
                           :: Func updF (vs :: toExpr_string nm :: v :: nil)
                           :: avail :: p' :: nil)
                       end
                  else None
            end
          | Symbolic base nms nm =>
            if Prover.(Prove) summ (Equal wordT p' base)
              && Prover.(Prove) summ (Equal listStringT nms ns)
              && Prover.(Prove) summ (Func InF (nm :: nms :: nil))
              then Some (ns
                :: Func updF (vs :: nm :: v :: nil)
                :: avail :: p' :: nil)
              else None
        end
      | _ => None
    end.
End parametric.

Definition MemEval : MEVAL.PredEval.MemEvalPred :=
  MEVAL.PredEval.Build_MemEvalPred sym_read sym_write (fun _ _ _ _ => None) (fun _ _ _ _ _ => None).

Section correctness.
  Variable types' : list type.
  Definition types0 := types types'.

  Definition ssig : SEP.predicate types0.
    refine (SEP.PSig _ (listStringT :: valsT :: natT :: wordT :: nil) _).
    exact locals.
  Defined.

  Definition ssig_r : Env.Repr (SEP.predicate types0) :=
    Eval cbv beta iota zeta delta [ Env.listOptToRepr ] in 
      let lst := 
        None :: None :: Some ssig :: nil
      in Env.listOptToRepr lst (SEP.Default_predicate _).

  Variable funcs' : functions types0.
  Definition funcs := Env.repr (funcs_r _) funcs'.

  Variable Prover : ProverT.
  Variable Prover_correct : ProverT_correct Prover funcs.

  Ltac doMatch P :=
    match P with
      | match ?E with 0 => _ | _ => _ end => destr2 idtac E
      | match ?E with nil => _ | _ => _ end => destr idtac E
      | match ?E with Var _ => _ | _ => _ end => destr2 idtac E
      | match ?E with tvProp => _ | _ => _ end => destr idtac E
      | match ?E with None => _ | _ => _ end => destr idtac E
      | match ?E with left _ => _ | _ => _ end => destr2 idtac E
      | match ?E with Nothing => _ | _ => _ end => destr2 idtac E
    end.

  Ltac deconstruct' :=
    match goal with
      | [ H : Some _ = Some _ |- _ ] => injection H; clear H; intros; subst
      | [ H : ?P |- _ ] =>
        let P := stripSuffix P in doMatch P
      | [ H : match ?P with None => _ | _ => _ end |- _ ] =>
        let P := stripSuffix P in doMatch P
      | [ |- match ?P with Nothing => _ | _ => _ end ] =>
        let P := stripSuffix P in doMatch P
    end.

  Ltac deconstruct := repeat deconstruct'.

  Lemma deref_correct : forall uvars vars e w,
    exprD funcs uvars vars e wordT = Some w
    -> match deref e with
         | Nothing => True
         | Constant base offset =>
           exists wb,
             exprD funcs uvars vars base wordT = Some wb
             /\ w = wb ^+ $(offset * 4)
         | Symbolic base nms nm =>
           exists wb nmsV nmV,
             exprD funcs uvars vars base wordT = Some wb
             /\ exprD funcs uvars vars nms listStringT = Some nmsV
             /\ exprD funcs uvars vars nm stringT = Some nmV
             /\ w = wb ^+ $(variablePosition nmsV nmV)
       end.
  Proof.
    destruct e; simpl deref; intuition; try discriminate.
    deconstruct.
    consider (toConst_nat e0); intros.
    { match goal with
        | [ |- context[div4 ?N] ] => specialize (div4_correct N);
                                    destruct (div4 N)
      end; intuition.
      specialize (H1 _ (refl_equal _)); subst.
      simpl in H.
      deconstruct.
      eapply toConst_nat_sound with (us := uvars) (vs := vars) (ts' := types0) (fs' := funcs) in H0.
      revert H0.
      match goal with
        | |- _ -> ?X =>
          change (exprD funcs uvars vars e0 natT = Some (4 * n0) -> X)
      end.
      intro. rewrite H0 in *.
      repeat (esplit || eassumption).
      inversion H; clear H; subst.
      repeat f_equal.
      unfold natToW.
      f_equal.
      omega. }
    { destruct e0; auto.
      do 22 (destruct f; auto).
      do 3 (destruct l; auto).
      simpl in H.
      deconstruct.
      destruct (exprD funcs uvars vars e0 listStringT); try discriminate.
      destruct (exprD funcs uvars vars e1 stringT); try discriminate.
      deconstruct; eauto 10. }
  Qed.

  Lemma listIn_correct : forall uvars vars e ns, listIn e = Some ns
    -> exprD funcs uvars vars e listStringT = Some ns.
  Proof.
    induction e; simpl; intuition; try discriminate.
    do 17 (destruct f; try discriminate).
    { destruct l; try discriminate. 
      inversion H0; clear H0; subst. reflexivity. }
    { destruct f; try discriminate.
      do 3 (destruct l; try discriminate).
      generalize (toConst_string_sound funcs e).
      destruct (toConst_string e); try discriminate; intros.
      specialize (H1 uvars vars). simpl.
      inversion H; clear H; subst.
      inversion H5; clear H5; subst.
      clear H6.
      consider (listIn e0); try discriminate; intros.
      inversion H0; clear H0; subst.
      specialize (H3 _ eq_refl).
      rewrite H3.
      cutrewrite (exprD funcs uvars vars e stringT = Some s).
      reflexivity. eapply H1. }    
  Qed.

  Lemma sym_sel_correct : forall uvars vars nm (vs : expr) vsv,
    exprD funcs uvars vars vs valsT = Some vsv
    -> exprD funcs uvars vars (sym_sel vs nm) wordT = Some (sel vsv nm).
  Proof.
    induction vs; simpl; intros; try discriminate.
    { rewrite H. rewrite toExpr_string_sound with (funcs' := funcs). reflexivity. }
    { rewrite H. rewrite toExpr_string_sound with (funcs' := funcs). reflexivity. }

    { assert (exprD funcs uvars vars (Func 18 (Func f l :: toExpr_string nm :: nil)) wordT = Some (sel vsv nm)).
      { simpl. 
        destruct (nth_error funcs f); try discriminate; intros.
        destruct (equiv_dec (Range s) valsT); try discriminate; intros.
        unfold equiv in *; subst. destruct s; simpl in *. subst.
        rewrite H0.
        rewrite toExpr_string_sound with (funcs' := funcs). reflexivity. }
      do 20 (destruct f; try assumption).
      do 4 (destruct l; try assumption).
      simpl in *.
      repeat match goal with
               | H : context [ match exprD funcs ?u ?v ?e ?t with _ => _ end ] |- _ =>
                 consider (exprD funcs u v e t); intros; try discriminate
               | H : Forall _ (_ :: _) |- _ => 
                 inversion H; clear H; subst
               | [ H : forall v, ?X = _ -> _ , H' : ?X = _ |- _ ] =>
                 specialize (H _ H')
               | H : Some _ = Some _ |- _ => inversion H; clear H; subst
             end.
      generalize (toConst_string_sound funcs e0).
      destruct (toConst_string e0); intros.
      { specialize (H uvars vars).
        revert H.
        match goal with
          | |- _ -> ?X =>
            change (exprD funcs uvars vars e0 stringT = Some s -> X)
        end.
        intro. rewrite H in *. inversion H1; clear H1; subst.
        consider (string_eq t0 nm); intros.
        { eapply string_eq_correct in H1. subst. rewrite H2.
          f_equal. 
          unfold sel, upd in *. rewrite H6.
          rewrite toExpr_string_sound with (funcs' := funcs) in H4. inversion H4; clear H4; subst.
          rewrite string_eq_true. reflexivity. }
        { rewrite toExpr_string_sound with (funcs' := funcs) in H4.
          inversion H4; clear H4; subst.
          rewrite H8.
          f_equal.
          unfold sel, upd.
          rewrite string_eq_false; auto. 
          intro. subst. rewrite string_eq_true in H1. discriminate. } }
      { simpl.
        repeat match goal with
                 | H : _ |- _ => rewrite H
               end. reflexivity. } } 
  Qed.

  Require Import NArith Nomega.

  Lemma array_selN : forall nm vs ns n,
    nth_error ns n = Some nm
    -> Array.selN (toArray ns vs) n = sel vs nm.
  Proof.
    induction ns; destruct n; simpl; intuition; try discriminate.
    injection H; clear H; intros; subst; reflexivity.
  Qed.

  Lemma length_toArray : forall ns vs,
    length (toArray ns vs) = length ns.
  Proof.
    induction ns; simpl; intuition.
  Qed.

  Fixpoint variablePosition' (ns : list string) (nm : string) : nat :=
    match ns with
      | nil => O
      | nm' :: ns' => if string_dec nm' nm then O
        else S (variablePosition' ns' nm)
    end.
  
  Lemma variablePosition'_4 : forall nm ns,
    variablePosition' ns nm * 4 = variablePosition ns nm.
    induction ns; simpl; intuition.
    destruct (string_dec a nm); intuition.
  Qed.

  Lemma nth_error_variablePosition' : forall nm ns,
    In nm ns
    -> nth_error ns (variablePosition' ns nm) = Some nm.
    induction ns; simpl; intuition; subst.
    destruct (string_dec nm nm); tauto.
    destruct (string_dec a nm); intuition; subst; auto.
  Qed.

  Lemma variablePosition'_length : forall nm ns,
    In nm ns
    -> (variablePosition' ns nm < length ns)%nat.
    induction ns; simpl; intuition; subst.
    destruct (string_dec nm nm); intuition.
    destruct (string_dec a nm); omega.
  Qed.

  Lemma toArray_irrel : forall vs v nm ns,
    ~In nm ns
    -> toArray ns (upd vs nm v) = toArray ns vs.
    induction ns; simpl; intuition.
    f_equal; auto.
    unfold upd.
    rewrite string_eq_false; auto.
  Qed.

  Lemma nth_error_In : forall A (x : A) ls n,
    nth_error ls n = Some x
    -> In x ls.
    induction ls; destruct n; simpl; intuition; try discriminate; eauto.
    injection H; intros; subst; auto.
  Qed.

  Lemma array_updN : forall vs nm v ns,
    NoDup ns
    -> forall n, nth_error ns n = Some nm
      -> Array.updN (toArray ns vs) n v
      = toArray ns (upd vs nm v).
    induction 1; destruct n; simpl; intuition.
    injection H1; clear H1; intros; subst.
    rewrite toArray_irrel by assumption.
    unfold upd; rewrite string_eq_true; reflexivity.
    rewrite IHNoDup; f_equal; auto.
    unfold upd; rewrite string_eq_false; auto.
    intro; subst.
    apply H.
    eapply nth_error_In; eauto.
  Qed.

  Lemma array_updN_variablePosition' : forall vs nm v ns,
    NoDup ns
    -> In nm ns
    -> toArray ns (upd vs nm v) = updN (toArray ns vs) (variablePosition' ns nm) v.
    induction 1; simpl; intuition; subst.
    destruct (string_dec nm nm); try tauto.
    rewrite toArray_irrel; auto.
    unfold upd.
    rewrite string_eq_true.
    auto.

    destruct (string_dec x nm); subst.
    rewrite toArray_irrel; auto.
    unfold upd.
    rewrite string_eq_true.
    auto.

    unfold upd at 1.
    rewrite string_eq_false by auto.
    rewrite H1; auto.
  Qed.

  Theorem sym_read_correct : forall args uvars vars cs summ pe p ve m stn,
    sym_read Prover summ args pe = Some ve ->
    Valid Prover_correct uvars vars summ ->
    exprD funcs uvars vars pe wordT = Some p ->
    match 
      applyD types0 (exprD funcs uvars vars) (SEP.SDomain ssig) args _ (SEP.SDenotation ssig)
      with
      | None => False
      | Some p => PropX.interp cs (p stn m)
    end ->
    match exprD funcs uvars vars ve wordT with
      | Some v =>
        smem_read_word stn p m = Some v
      | _ => False
    end.
  Proof.
    simpl; intuition.
    do 5 (destruct args; simpl in *; intuition; try discriminate).
    generalize (deref_correct uvars vars pe); destruct (deref pe); intro Hderef; try discriminate.

    { generalize (listIn_correct uvars vars e); destr idtac (listIn e); intro HlistIn.
      specialize (HlistIn _ (refl_equal _)).
      rewrite HlistIn in *.
      repeat match goal with
               | [ H : Valid _ _ _ _, _ : context[Prove Prover ?summ ?goal] |- _ ] =>
                 match goal with
                   | [ _ : context[ValidProp _ _ _ goal] |- _ ] => fail 1
                   | _ => specialize (Prove_correct Prover_correct summ H (goal := goal)); intro
                 end
             end; unfold ValidProp in *.
      unfold types0 in *.
      match type of H with
        | (if ?E then _ else _) = _ => destruct E
      end; intuition; try discriminate.
      simpl in H4.
      case_eq (nth_error l n); [ intros ? Heq | intro Heq ]; rewrite Heq in *; try discriminate.
      injection H; clear H; intros; subst.
      generalize (sym_sel_correct uvars vars s e0); intro Hsym_sel.
      destruct (exprD funcs uvars vars e0 valsT); try tauto.
      specialize (Hsym_sel _ (refl_equal _)).
      rewrite Hsym_sel.
      specialize (Hderef _ H1).
      destruct Hderef as [ ? [ ] ].
      subst.
      unfold types0 in H2.
      unfold types0 in H1.
      case_eq (exprD funcs uvars vars e1 natT); [ intros ? Heq' | intro Heq' ]; rewrite Heq' in *; try tauto.
      case_eq (exprD funcs uvars vars e2 wordT); [ intros ? Heq'' | intro Heq'' ]; rewrite Heq'' in *; try tauto.
      rewrite H in H4.
      specialize (H4 (ex_intro _ _ (refl_equal _))).
      hnf in H4; simpl in H4.
      rewrite Heq'' in H4.
      rewrite H in H4.
      subst.
      Require Import PropXTac.
      apply simplify_fwd in H2.
      destruct H2 as [ ? [ ? [ ? [ ] ] ] ].
      destruct H3 as [ ? [ ? [ ? [ ] ] ] ].
      simpl simplify in H2, H3, H5.
      destruct H5.
      apply simplify_bwd in H6.
      subst.
      eapply split_emp in H3. red in H3. subst. 
      specialize (smem_read_correct' _ _ _ _ (i := natToW n) H6); intro Hsmem.
      rewrite natToW_times4.
      rewrite wmult_comm.
      unfold natToW in *.
      unfold smem_read_word.
      erewrite MSMF.split_multi_read. 3: eapply Hsmem. 2: eassumption. 

      f_equal.
      unfold Array.sel.
      apply array_selN.
      apply array_bound in H6.
      rewrite wordToNat_natToWord_idempotent; auto.
      apply nth_error_Some_length in Heq. 

      rewrite length_toArray in *.
      apply Nlt_in.
      rewrite Nat2N.id.
      rewrite Npow2_nat.
      omega.

      rewrite length_toArray.
      apply Nlt_in.
      repeat rewrite wordToN_nat.
      repeat rewrite Nat2N.id.
      apply array_bound in H6.
      rewrite length_toArray in *.
      repeat rewrite wordToNat_natToWord_idempotent.
      eapply nth_error_Some_length; eauto.
      apply Nlt_in.
      rewrite Nat2N.id.
      rewrite Npow2_nat.
      omega.
      apply Nlt_in.
      rewrite Nat2N.id.
      rewrite Npow2_nat.
      apply nth_error_Some_length in Heq.
      omega. }

    (* Now the [Symbolic] case... *)
    { repeat match goal with
               | [ H : Valid _ _ _ _, _ : context[Prove Prover ?summ ?goal] |- _ ] =>
                 match goal with
                   | [ _ : context[ValidProp _ _ _ goal] |- _ ] => fail 1
                   | _ => specialize (Prove_correct Prover_correct summ H (goal := goal)); intro
                 end
             end; unfold ValidProp in *.
      unfold types0 in *.
      match type of H with
        | (if ?E then _ else _) = _ => case_eq E
      end; intuition; match goal with
                        | [ H : _ = _ |- _ ] => rewrite H in *
                      end; try discriminate.
      simpl in H3, H4, H5.
      apply andb_prop in H6; destruct H6.
      apply andb_prop in H6; destruct H6.
      intuition.
      destruct (Hderef _ H1) as [ ? [ ? [ ] ] ]; clear Hderef; intuition; subst.
      rewrite H10 in *.
      rewrite H5 in *.
      rewrite H11 in *.
      specialize (H4 (ex_intro _ _ (refl_equal _))).
      unfold Provable in H4.
      injection H; clear H; intros; subst.
      simpl exprD in *.
      unfold types0 in *.
      unfold Provable in *.
      simpl exprD in *.
      deconstruct.
      rewrite H10 in *.
      specialize (H3 (ex_intro _ _ (refl_equal _))).
      specialize (H9 (ex_intro _ _ (refl_equal _))).
      subst.
      apply simplify_fwd in H2.
      destruct H2.
      destruct H.
      destruct H.
      destruct H2.
      destruct H2.
      destruct H2.
      destruct H2.
      destruct H5.
      simpl in H.
      simpl in H2.
      simpl in H5.
      destruct H5.
      subst.
      eapply split_emp in H2. red in H2; subst.
      apply simplify_bwd in H9.

      specialize (smem_read_correct' _ _ _ _ (i := natToW (variablePosition' t x1)) H9); intro Hsmem.
      rewrite wmult_comm in Hsmem.
      rewrite <- natToW_times4 in Hsmem.

      rewrite variablePosition'_4 in Hsmem.
      unfold smem_read_word.
      erewrite MSMF.split_multi_read. 3: eapply Hsmem. 2: eassumption.
      f_equal.
      unfold Array.sel.
      apply array_selN.
      apply array_bound in H9.
      rewrite wordToNat_natToWord_idempotent; auto.

      apply nth_error_variablePosition'; auto.
      rewrite length_toArray in *.
      apply Nlt_in.
      rewrite Nat2N.id.
      rewrite Npow2_nat.

      specialize (variablePosition'_length _ _ H4).
      omega.

      red.
      apply array_bound in H9.    
      repeat rewrite wordToN_nat.
      rewrite wordToNat_natToWord_idempotent.
      rewrite wordToNat_natToWord_idempotent.
      apply Nlt_in.
      repeat rewrite Nat2N.id.
      rewrite length_toArray.
      apply variablePosition'_length; auto.
      apply Nlt_in.
      rewrite Npow2_nat.
      repeat rewrite Nat2N.id.
      assumption.
      apply Nlt_in.
      rewrite Npow2_nat.
      repeat rewrite Nat2N.id.
      specialize (variablePosition'_length _ _ H4).
      rewrite length_toArray in H9.
      omega. }
  Qed.

  Theorem sym_write_correct : forall args uvars vars cs summ pe p ve v m stn args',
    sym_write Prover summ args pe ve = Some args' ->
    Valid Prover_correct uvars vars summ ->
    exprD funcs uvars vars pe wordT = Some p ->
    exprD funcs uvars vars ve wordT = Some v ->
    match
      applyD types0 (@exprD _ funcs uvars vars) (SEP.SDomain ssig) args _ (SEP.SDenotation ssig)
      with
      | None => False
      | Some p => PropX.interp cs (p stn m)
    end ->
    match 
      applyD types0 (@exprD _ funcs uvars vars) (SEP.SDomain ssig) args' _ (SEP.SDenotation ssig)
      with
      | None => False
      | Some pr => 
        match smem_write_word stn p v m with
          | None => False
          | Some sm' => PropX.interp cs (pr stn sm')
        end
    end.
  Proof.
    simpl; intuition.
    do 5 (destruct args; simpl in *; intuition; try discriminate).
    generalize (deref_correct uvars vars pe); destruct (deref pe); intro Hderef; try discriminate.

    generalize (listIn_correct uvars vars e); destr idtac (listIn e); intro HlistIn;
      specialize (HlistIn _ (refl_equal _)); rewrite HlistIn in *.
    destruct (Hderef _ H1); clear Hderef; intuition; subst.
    repeat match goal with
             | [ H : Valid _ _ _ _, _ : context[Prove Prover ?summ ?goal] |- _ ] =>
               match goal with
                 | [ _ : context[ValidProp _ _ _ goal] |- _ ] => fail 1
                 | _ => specialize (Prove_correct Prover_correct summ H (goal := goal)); intro
               end
           end; unfold ValidProp in *.
    unfold types0 in *.
    match type of H with
      | (if ?E then _ else _) = _ => destruct E
    end; intuition; try discriminate.
    simpl in H5.
    case_eq (nth_error l n); [ intros ? Heq | intro Heq ]; rewrite Heq in *; try discriminate.
    injection H; clear H; intros; subst.
    unfold applyD.
    rewrite HlistIn.
    simpl exprD.
    destruct (exprD funcs uvars vars e0 valsT); try tauto.
    unfold Provable in H6.
    simpl in H6.
    rewrite H5 in H6.
    destruct (exprD funcs uvars vars e1 natT); try tauto.
    destruct (exprD funcs uvars vars e2 wordT); try tauto.
    rewrite H2.
    specialize (H6 (ex_intro _ _ (refl_equal _))); subst.
    apply simplify_fwd in H3.
    destruct H3 as [ ? [ ? [ ? [ ] ] ] ].
    destruct H3 as [ ? [ ? [ ? [ ] ] ] ].
    simpl in H, H3, H6, H7.
    destruct H6.
    apply simplify_bwd in H7.
    eapply smem_write_correct' in H7.
    destruct H7 as [ ? [ ] ].
    rewrite natToW_times4.
    rewrite wmult_comm.
    subst.
    eapply split_emp in H3. red in H3; subst.
    eapply MSMF.split_multi_write in H7. 2: eassumption.
    destruct H7.
    destruct H3. unfold smem_write_word. rewrite H7.
    unfold locals.
    rewrite toExpr_string_sound with (funcs' := funcs).
    apply simplify_bwd.
    exists x4; exists x1. split. apply H3.
    split. exists smem_emp. exists x4. split.
    eapply split_emp. reflexivity.
    split. split; simpl; auto.

    apply simplify_fwd.
    unfold Array.upd in H9.
    rewrite wordToNat_natToWord_idempotent in H9.
    erewrite array_updN in H9; eauto.
    apply nth_error_Some_length in Heq.
    apply array_bound in H9.

    rewrite updN_length in H9.
    rewrite length_toArray in H9.
    apply Nlt_in.
    rewrite Nat2N.id.
    rewrite Npow2_nat.
    omega.

    destruct H; auto.

    rewrite length_toArray.
    apply Nlt_in.
    repeat rewrite wordToN_nat.
    repeat rewrite Nat2N.id.
    apply array_bound in H7.
    rewrite length_toArray in *.
    repeat rewrite wordToNat_natToWord_idempotent.
    eapply nth_error_Some_length; eauto.
    apply Nlt_in.
    rewrite Nat2N.id.
    rewrite Npow2_nat.
    omega.
    apply Nlt_in.
    rewrite Nat2N.id.
    rewrite Npow2_nat.
    apply nth_error_Some_length in Heq.
    omega.


    (* Now the [Symbolic] case... *)

    { destruct (Hderef _ H1) as [ ? [ ? [ ? [ ] ] ] ]; clear Hderef; intuition; subst.
      repeat match goal with
               | [ H : Valid _ _ _ _, _ : context[Prove Prover ?summ ?goal] |- _ ] =>
                 match goal with
                   | [ _ : context[ValidProp _ _ _ goal] |- _ ] => fail 1
                   | _ => specialize (Prove_correct Prover_correct summ H (goal := goal)); intro
                 end
             end; unfold ValidProp in *.
      unfold types0 in *.
      match type of H with
        | (if ?E then _ else _) = _ => case_eq E
      end; intuition; match goal with
                        | [ H : _ = _ |- _ ] => rewrite H in *
                      end; try discriminate.
      simpl in H7, H8, H9.
      apply andb_prop in H10; destruct H10.
      apply andb_prop in H10; destruct H10.
      intuition.
      injection H; clear H; intros; subst.
      simpl applyD.
      unfold Provable in *.
      simpl exprD in *.
      deconstruct.
      repeat match goal with
               | [ H : _ = _ |- _ ] => rewrite H in *
               | [ H : _ |- _ ] => specialize (H (ex_intro _ _ (refl_equal _))); subst
             end.
      apply simplify_fwd in H3.
      destruct H3.
      destruct H.
      destruct H.
      simpl in H.
      destruct H3.
      destruct H3.
      destruct H3.
      destruct H3.
      simpl in H3.
      destruct H9.
      simpl in H9.
      destruct H9.
      apply simplify_bwd in H13.
      subst.
      eapply split_emp in H3. red in H3; subst.
      eapply smem_write_correct' in H13.
      destruct H13 as [ ? [ ] ].
      rewrite <- variablePosition'_4.
      rewrite natToW_times4.
      rewrite wmult_comm.
      eapply MSMF.split_multi_write in H3. 2: eassumption.
      destruct H3. destruct H3.
      unfold smem_write_word. rewrite H14.
      apply simplify_bwd.
      esplit.
      esplit.
      split.
      simpl.
      eassumption.
      esplit.
      esplit.
      esplit.
      esplit.
      simpl.
      2: split; simpl; eauto.
      eapply split_emp. reflexivity.
      apply simplify_fwd.
      unfold Array.upd in H13.
      rewrite wordToNat_natToWord_idempotent in H13.
      
      rewrite array_updN_variablePosition'; auto.

      apply array_bound in H13.
      rewrite updN_length in H13.
      apply Nlt_in.
      rewrite Npow2_nat.
      repeat rewrite Nat2N.id.
      apply variablePosition'_length in H8.
      rewrite length_toArray in H13.
      omega.

      assumption.

      rewrite length_toArray.
      apply Nlt_in.
      repeat rewrite wordToN_nat.
      repeat rewrite Nat2N.id.
      rewrite wordToNat_natToWord_idempotent.
      rewrite wordToNat_natToWord_idempotent.
      apply variablePosition'_length; auto.
      apply array_bound in H13.
      apply Nlt_in.
      rewrite Npow2_nat.
      repeat rewrite Nat2N.id.
      rewrite length_toArray in H13.
      assumption.

      apply Nlt_in.
      rewrite Npow2_nat.
      repeat rewrite wordToN_nat.
      repeat rewrite Nat2N.id.
      apply array_bound in H13.
      generalize (variablePosition'_length _ _ H8).
      rewrite length_toArray in H13.
      omega. }
  Qed.

End correctness.

Definition MemEvaluator : MEVAL.MemEvaluator :=
  Eval cbv beta iota zeta delta [ MEVAL.PredEval.MemEvalPred_to_MemEvaluator ] in 
    @MEVAL.PredEval.MemEvalPred_to_MemEvaluator MemEval 2.

Theorem MemEvaluator_correct types' funcs' preds'
  : @MEVAL.MemEvaluator_correct (Env.repr types_r types') (tvType 0) (tvType 1) 
  MemEvaluator (funcs funcs') (Env.repr (ssig_r _) preds')
  (IL.settings * IL.state) (tvType 0) (tvType 0)
  (@IL_mem_satisfies (types types')) (@IL_ReadWord (types types')) (@IL_WriteWord (types types'))
  (@IL_ReadByte (types types')) (@IL_WriteByte (types types')).
Proof.
  intros. eapply (@MemPredEval_To_MemEvaluator_correct (types types')); try reflexivity;
  intros; unfold MemEval in *; simpl in *; try discriminate.
  { generalize (@sym_read_correct (types types') funcs' P PE). simpl in *. intro.
    eapply H3 in H; eauto. }
  { generalize (@sym_write_correct (types types') funcs' P PE). simpl in *. intro.
    eapply H4 in H; eauto. }
Qed.

Definition pack : MEVAL.MemEvaluatorPackage types_r (tvType 0) (tvType 1) (tvType 0) (tvType 0)
  IL_mem_satisfies IL_ReadWord IL_WriteWord IL_ReadByte IL_WriteByte :=

  @MEVAL.Build_MemEvaluatorPackage types_r (tvType 0) (tvType 1) (tvType 0) (tvType 0) 
  IL_mem_satisfies IL_ReadWord IL_WriteWord IL_ReadByte IL_WriteByte
  types_r
  funcs_r
  (fun ts => Env.listOptToRepr (None :: None :: Some (ssig ts) :: nil)
    (SEP.Default_predicate (Env.repr types_r ts)))
  MemEvaluator
  (fun ts fs ps => @MemEvaluator_correct (types ts) _ _).


(** * Some additional helpful theorems *)

Theorem sel_upd_eq : forall vs nm v nm',
  nm = nm'
  -> sel (upd vs nm v) nm' = v.
Proof.
  unfold sel, upd; intros; subst; rewrite string_eq_true; reflexivity.
Qed.

Theorem sel_upd_ne : forall vs nm v nm',
  nm <> nm'
  -> sel (upd vs nm v) nm' = sel vs nm'.
Proof.
  unfold sel, upd; intros; subst; rewrite string_eq_false; auto.
Qed.

Ltac simp := cbv beta; unfold In.

(** ** Point-of-view switch at function call sites *)

Lemma behold_the_array' : forall p ns,
  NoDup ns
  -> forall offset, allocated p offset (length ns)
    ===> Ex vs, ptsto32m' nil p offset (toArray ns vs).
Proof.
  induction 1; simpl length; unfold allocated; fold allocated; intros.

  { simpl.
    apply himp_ex_c. 
    exists (fun _ => wzero _).
    apply Himp_refl. }

  { eapply Himp_trans; [ apply himp_ex_star | ].
    apply himp_ex_p; intro.
    eapply Himp_trans; [ eapply himp_star_frame | ]; [ apply Himp_refl | apply IHNoDup | ].
    eapply Himp_trans; [ apply himp_star_comm | ].
    eapply Himp_trans; [ apply himp_ex_star | ].
    eapply himp_ex_p; intro.
    simpl toArray.
    unfold ptsto32m'; fold ptsto32m'.

    replace (match offset with
               | 0 => p
               | S _ => p ^+ $ (offset)
             end) with (p ^+ $(offset)) by (destruct offset; W_eq).
  
    apply himp_ex_c; exists (upd v0 x v).
    eapply Himp_trans; [ apply himp_star_comm | ].
    apply himp_star_frame.
    change (upd v0 x v x) with (sel (upd v0 x v) x).
    rewrite sel_upd_eq by reflexivity.
    apply Himp_refl.

    rewrite toArray_irrel by assumption.
    apply Himp_refl. }
Qed.

Theorem Himp_star_Emp : forall P,
  Emp * P ===> P.
Proof.
  intros.
  eapply himp_star_emp_p.
Qed.

Theorem ptsto32m'_out : forall a vs offset,
  ptsto32m' _ a offset vs ===> ptsto32m _ a offset vs.
Proof.
  induction vs; intros.

  apply Himp_refl.

  unfold ptsto32m', ptsto32m; fold ptsto32m; fold ptsto32m'.
  replace (match offset with
             | 0 => a
             | S _ => a ^+ $ (offset)
           end) with (a ^+ $(offset)) by (destruct offset; W_eq).
  destruct vs.
  simpl ptsto32m'.
  eapply Himp_trans; [ apply himp_star_comm | ].
  apply Himp_star_Emp.
  apply himp_star_frame.
  apply Himp_refl.
  eapply IHvs.
Qed.

Theorem Himp_ex : forall T (P Q : T -> _), 
  (forall v, P v ===> Q v) ->
  ex P ===> ex Q.
  intros; intro cs; apply himp_ex; firstorder.
Qed.

Lemma behold_the_array : forall p ns,
  NoDup ns
  -> forall offset, allocated p offset (length ns)
    ===> Ex vs, ptsto32m nil p offset (toArray ns vs).
  intros.
  eapply Himp_trans; [ apply behold_the_array' | ]; auto.
  apply Himp_ex; intro.
  apply ptsto32m'_out.
Qed.

Lemma do_call' : forall ns ns' vs avail avail' p p',
  (length ns' <= avail)%nat
  -> avail' = avail - length ns'
  -> p' = p ^+ natToW (4 * length ns)
  -> NoDup ns'
  -> locals ns vs avail p ===> locals ns vs 0 p * Ex vs', locals ns' vs' avail' p'.
Proof.
  intros.
  unfold locals.
  eapply Himp_trans; [ | apply heq_star_assoc ]. 
  apply himp_star_frame.
  apply Himp_refl.

  subst.
  eapply Himp_trans; [ | apply himp_star_emp_c ].
  eapply Himp_trans; [ apply allocated_split | ]; eauto.
  replace (0 + 4 * length ns') with (length ns' * 4) by omega.
  replace (4 * length ns) with (length ns * 4) by omega.
  eapply Himp_trans.
  eapply himp_star_frame.
  apply behold_the_array; auto.
  apply Himp_refl.
  rewrite heq_ex_star.
  apply himp_ex_p; intro vs'.
  apply himp_ex_c; exists vs'.
  unfold array.  
  rewrite heq_star_assoc.
  apply himp_star_pure_cc; auto.
  apply himp_star_frame.
  apply Himp_refl.
  apply allocated_shift_base; auto.
  unfold natToW; W_eq.
Qed.

Definition reserved (p : W) (len : nat) := (p =?> len)%Sep.

Ltac words' := repeat (rewrite (Mult.mult_comm 4)
  || rewrite natToW_times4 || rewrite natToW_plus); unfold natToW.
Ltac words := words'; W_eq.

Lemma expose_avail : forall ns vs avail p expose avail',
  (expose <= avail)%nat
  -> avail' = avail - expose
  -> locals ns vs avail p ===> locals ns vs avail' p
  * reserved (p ^+ natToW (4 * (length ns + avail'))) expose.
Proof.
  unfold locals; intros.
  eapply Himp_trans; [ | apply heq_star_assoc ]. 
  apply himp_star_frame.
  apply Himp_refl.  
  subst.
  eapply Himp_trans; [ apply allocated_split | ].
  instantiate (1 := avail - expose); omega.
  apply himp_star_frame.
  apply Himp_refl.
  apply allocated_shift_base; try omega.
  words.
Qed.

Theorem Himp_refl' : forall P Q,
  P = Q
  -> P ===> Q.
  intros; subst; apply Himp_refl.
Qed.

Theorem do_call : forall ns ns' vs avail avail' p p',
  (length ns' <= avail)%nat
  -> (avail' <= avail - length ns')%nat
  -> p' = p ^+ natToW (4 * length ns)
  -> NoDup ns'
  -> locals ns vs avail p ===>
  locals ns vs 0 p
  * Ex vs', locals ns' vs' avail' p'
  * reserved (p ^+ natToW (4 * (length ns + length ns' + avail')))
  (avail - length ns' - avail').
Proof.
  intros; subst.
  eapply Himp_trans; [ apply do_call' | ]; eauto.
  apply himp_star_frame; [ apply Himp_refl | ].
  apply Himp_ex; intro.
  eapply Himp_trans; [ apply expose_avail | ].
  instantiate (1 := avail - length ns' - avail'); omega.
  eauto.
  apply himp_star_frame.
  apply Himp_refl'.
  f_equal; omega.
  apply Himp_refl'.
  f_equal.
  words'.
  replace (avail - Datatypes.length ns' -
    (avail - Datatypes.length ns' - avail'))
    with avail' by omega.
  W_eq.
Qed.

Lemma ptsto32m'_allocated : forall (p : W) (ls : list W) (offset : nat),
  ptsto32m' nil p offset ls ===> allocated p offset (length ls).
Proof.
  induction ls.

  intros; apply Himp_refl.

  simpl length.
  unfold ptsto32m', allocated; fold ptsto32m'; fold allocated.
  intros.
  replace (match offset with
             | 0 => p
             | S _ => p ^+ $ (offset)
           end) with (p ^+ $(offset)) by (destruct offset; W_eq).
  apply himp_star_frame.
  apply himp_ex_c; eexists; apply Himp_refl.
  eapply IHls.
Qed.

Lemma ptsto32m_ptsto32m'_himp : forall ls p offset,
  ptsto32m nil p offset ls ===> ptsto32m' nil p offset ls.
Proof.
  induction ls; intros.
  { simpl ptsto32m'; simpl ptsto32m. eapply Himp_refl. }
  { unfold ptsto32m'; fold ptsto32m'.
    unfold ptsto32m; fold ptsto32m.
    destruct ls; destruct offset; try (rewrite wplus_comm; rewrite wplus_unit).
    { rewrite heq_star_comm. eapply himp_star_emp_c. }
    { rewrite heq_star_comm. eapply himp_star_emp_c. }
    { rewrite IHls; reflexivity. }
    { rewrite IHls; reflexivity. } }
Qed.

Lemma ptsto32m_allocated : forall (p : W) (ls : list W) (offset : nat),
  ptsto32m nil p offset ls ===> allocated p offset (length ls).
Proof.
  intros; eapply Himp_trans.
  eapply ptsto32m_ptsto32m'_himp.
  apply ptsto32m'_allocated.
Qed.

Lemma do_return' : forall ns ns' vs avail avail' p p',
  avail = avail' + length ns'
  -> p' = p ^+ natToW (4 * length ns)
  -> (locals ns vs 0 p * Ex vs', locals ns' vs' avail' p') ===> locals ns vs avail p.
Proof.
  unfold locals; intros.
  eapply Himp_trans; [ apply himp_star_assoc | ].
  apply himp_star_frame; [ apply Himp_refl | ].
  unfold allocated; fold allocated.
  eapply Himp_trans; [ apply Himp_star_Emp | ].
  apply himp_ex_p; intro vs'.
  eapply Himp_trans; [ apply himp_star_assoc | ].
  apply himp_star_pure_c; intro.
  subst.
  eapply Himp_trans; [ | apply allocated_join ].
  2: instantiate (1 := length ns'); omega.
  apply himp_star_frame.
  unfold array.
  words'.
  replace (length ns') with (length (toArray ns' vs')) by apply length_toArray.
  apply ptsto32m_allocated.
  apply allocated_shift_base; try omega.
  words.
Qed.

Lemma unexpose_avail : forall ns vs avail p expose avail',
  (expose <= avail)%nat
  -> avail' = avail - expose
  -> locals ns vs avail' p
  * reserved (p ^+ natToW (4 * (length ns + avail'))) expose
  ===> locals ns vs avail p.
Proof.
  unfold locals; intros.
  eapply Himp_trans; [ apply himp_star_assoc | ].
  apply himp_star_frame; [ apply Himp_refl | ].
  eapply Himp_trans; [ | apply allocated_join ].
  2: instantiate (1 := avail'); omega.
  apply himp_star_frame; [ apply Himp_refl | ].
  apply allocated_shift_base; try omega.
  subst.
  words.
Qed.

Lemma do_return : forall ns ns' vs avail avail' p p',
  (avail >= avail' + length ns')%nat
  -> p' = p ^+ natToW (4 * length ns)
  -> (locals ns vs 0 p * Ex vs', locals ns' vs' avail' p'
    * reserved (p ^+ natToW (4 * (length ns + length ns' + avail')))
    (avail - length ns' - avail'))
    ===> locals ns vs avail p.
Proof.
  intros.
  eapply Himp_trans; [ | apply do_return' ].
  3: eassumption.
  Focus 2.
  instantiate (1 := ns').
  instantiate (1 := (avail - avail' - length ns') + avail').
  omega.
  apply himp_star_frame; [ apply Himp_refl | ].
  apply Himp_ex; intro vs'.
  unfold locals.
  eapply Himp_trans; [ apply himp_star_assoc | ].
  apply himp_star_frame; [ apply Himp_refl | ].
  eapply Himp_trans; [ | apply allocated_join ].
  2: instantiate (1 := avail'); omega.
  apply himp_star_frame; [ apply Himp_refl | ].
  apply allocated_shift_base; try omega.
  subst.
  words.
Qed.

(** ** Point-of-view switch in function preludes *)

Definition agree_on (vs vs' : vals) (ns : list string) :=
  List.Forall (fun nm => sel vs nm = sel vs' nm) ns.

Fixpoint merge (vs vs' : vals) (ns : list string) :=
  match ns with
    | nil => vs'
    | nm :: ns' => upd (merge vs vs' ns') nm (sel vs nm)
  end.

Lemma Forall_weaken : forall A (P P' : A -> Prop),
  (forall x, P x -> P' x)
  -> forall ls, List.Forall P ls
    -> List.Forall P' ls.
Proof.
  induction 2; simpl; intuition.
Qed.

Theorem merge_agree : forall vs vs' ns,
  agree_on (merge vs vs' ns) vs ns.
Proof.
  induction ns; simpl; intuition; constructor.
  unfold sel, upd.
  rewrite string_eq_true; reflexivity.
  eapply Forall_weaken; [ | eassumption ].
  simpl; intros.
  destruct (string_dec a x); subst.
  apply sel_upd_eq; reflexivity.
  rewrite sel_upd_ne; assumption.
Qed.

Lemma NoDup_unapp2 : forall A (ls1 ls2 : list A),
  NoDup (ls1 ++ ls2)
  -> NoDup ls2.
Proof.
  induction ls1; inversion 1; simpl in *; intuition.
Qed.

Lemma toArray_vals_eq : forall vs vs' ns, agree_on vs vs' ns
  -> toArray ns vs = toArray ns vs'.
Proof.
  induction ns; simpl; intuition.
  inversion H; clear H; subst.
  f_equal; auto.
Qed.

Lemma agree_on_symm : forall vs vs' nm, agree_on vs vs' nm
  -> agree_on vs' vs nm.
Proof.
  intros; eapply Forall_weaken; [ | eauto ].
  intuition.
Qed.

Lemma Forall_weaken' : forall A (P P' : A -> Prop) ls,
  List.Forall P ls
  -> (forall x, In x ls -> P x -> P' x)
  -> List.Forall P' ls.
Proof.
  induction 1; simpl; intuition.
Qed.

Lemma ptsto32m'_merge : forall p vs' ns' ns offset vs vs'',
  NoDup (ns ++ ns')
  -> agree_on vs'' (merge vs vs' ns) (ns ++ ns')
  -> ptsto32m' nil p offset (toArray ns vs)
  * ptsto32m' nil p (offset + 4 * length ns) (toArray ns' vs')
  ===> ptsto32m' nil p offset (toArray (ns ++ ns') vs'').
Proof. 
  induction ns; simpl app; intros.

  simpl.
  eapply Himp_trans; [ apply Himp_star_Emp | ].
  apply Himp_refl'.
  f_equal.
  omega.
  simpl in *.
  apply toArray_vals_eq; auto.
  apply agree_on_symm; auto.

  inversion H; clear H; subst.
  simpl in H0.
  simpl toArray; simpl length.
  unfold ptsto32m'; fold ptsto32m'.
  eapply Himp_trans; [ apply himp_star_assoc | ].
  apply himp_star_frame.
  apply Himp_refl'.
  f_equal.
  assert (Hin : In a (a :: ns ++ ns')) by (simpl; tauto).
  apply (proj1 (Forall_forall _ _) H0) in Hin.
  rewrite sel_upd_eq in Hin by reflexivity.
  symmetry; assumption.

  eapply Himp_trans; [ | apply IHns ]; auto.
  apply himp_star_frame.
  apply Himp_refl.
  apply Himp_refl'; f_equal; omega.

  inversion H0; clear H0; subst.
  eapply Forall_weaken'.
  eassumption.
  simpl; intros.
  rewrite H0.
  destruct (string_dec a x); subst.
  tauto.
  rewrite sel_upd_ne by assumption; reflexivity.
Qed.

Lemma ptsto32m_merge : forall p vs' ns' ns offset vs vs'',
  NoDup (ns ++ ns')
  -> agree_on vs'' (merge vs vs' ns) (ns ++ ns')
  -> ptsto32m nil p offset (toArray ns vs)
  * ptsto32m nil p (offset + 4 * length ns) (toArray ns' vs')
  ===> ptsto32m nil p offset (toArray (ns ++ ns') vs'').
Proof.
  intros.
  eapply Himp_trans.
  apply himp_star_frame; apply ptsto32m_ptsto32m'_himp.
  eapply Himp_trans; [ | apply ptsto32m'_out ].
  apply ptsto32m'_merge; auto.
Qed.

Lemma agree_on_refl : forall vs ns,
  agree_on vs vs ns.
Proof.
  unfold agree_on; induction ns; simpl; intuition.
Qed.

Lemma ptsto32m'_shift_base : forall p n ls offset,
  (n <= offset)%nat
  -> ptsto32m' nil (p ^+ $(n)) (offset - n) ls
  ===> ptsto32m' nil p offset ls.
Proof.
  induction ls.

  intros; apply Himp_refl.

  unfold ptsto32m'; fold ptsto32m'.
  intros.
  intro; apply himp_star_frame.
  apply Himp_refl'; f_equal.
  rewrite <- wplus_assoc.
  rewrite <- natToW_plus.
  unfold natToW.
  repeat f_equal.
  omega.
  replace (4 + (offset - n)) with ((4 + offset) - n) by omega.
  apply IHls; omega.
Qed.

Lemma ptsto32m_shift_base : forall p n ls offset,
  (n <= offset)%nat
  -> ptsto32m nil (p ^+ $(n)) (offset - n) ls
  ===> ptsto32m nil p offset ls.
Proof.
  intros; eapply Himp_trans.
  apply ptsto32m_ptsto32m'_himp.
  eapply Himp_trans.
  apply ptsto32m'_shift_base; auto.
  apply ptsto32m'_out.
Qed.

Theorem prelude_in : forall ns ns' vs avail p,
  (length ns' <= avail)%nat
  -> NoDup (ns ++ ns')
  -> locals ns vs avail p ===>
  Ex vs', locals (ns ++ ns') (merge vs vs' ns) (avail - length ns') p.
Proof.
  unfold locals; intros.
  eapply Himp_trans; [ apply himp_star_assoc | ].
  apply himp_star_pure_c; intro Hns.
  eapply Himp_trans.
  eapply himp_star_frame; [ apply Himp_refl | ].
  eapply allocated_split.
  eassumption.
  rewrite <- heq_star_assoc.
  eapply Himp_trans.
  eapply himp_star_frame.
  apply himp_star_comm.
  apply Himp_refl.
  eapply Himp_trans; [ apply himp_star_assoc | ].
  eapply Himp_trans.
  eapply himp_star_frame.
  apply behold_the_array.
  eapply NoDup_unapp2; eauto.
  apply Himp_refl.
  eapply Himp_trans; [ apply himp_ex_star | ].
  apply Himp_ex; intro vs'.
  unfold array.
  eapply Himp_trans; [ | apply heq_star_assoc ].
  apply himp_star_pure_cc; auto.
  eapply Himp_trans; [ apply heq_star_assoc | ].
  apply himp_star_frame.
  eapply Himp_trans; [ | apply ptsto32m_merge ]; eauto.
  eapply Himp_trans; [ apply himp_star_comm | ].
  apply himp_star_frame.
  apply Himp_refl.
  match goal with
    | [ |- himp ?P _ ] =>
      replace P
    with (ptsto32m nil (p ^+ $ (Datatypes.length ns * 4)) (0 + 4 * length ns - length ns * 4) (toArray ns' vs'))
      by (f_equal; omega)
  end.
  apply ptsto32m_shift_base.
  omega.
  apply agree_on_refl.
  
  apply allocated_shift_base; try omega.
  rewrite app_length.
  words.
Qed.

Lemma ptsto32m'_split : forall p ns' ns offset vs,
  ptsto32m' nil p offset (toArray (ns ++ ns') vs)
  ===> ptsto32m' nil p offset (toArray ns vs)
  * ptsto32m' nil p (offset + 4 * length ns) (toArray ns' vs).
Proof.
  induction ns.

  simpl.
  intros.
  rewrite <- himp_star_emp_c.
  apply Himp_refl'; f_equal; omega.

  simpl toArray; simpl length.
  unfold ptsto32m'; fold ptsto32m'.
  intros.

  eapply Himp_trans; [ | apply heq_star_assoc ].
  apply himp_star_frame; [ apply Himp_refl | ].
  eapply Himp_trans; [ apply IHns | ].
  apply himp_star_frame; [ apply Himp_refl | ].
  apply Himp_refl'; f_equal; omega.
Qed.

Lemma ptsto32m_split : forall p ns' ns offset vs,
  ptsto32m nil p offset (toArray (ns ++ ns') vs)
  ===> ptsto32m nil p offset (toArray ns vs)
  * ptsto32m nil p (offset + 4 * length ns) (toArray ns' vs).
Proof.
  intros; eapply Himp_trans.
  apply ptsto32m_ptsto32m'_himp.
  eapply Himp_trans.
  apply ptsto32m'_split.
  apply himp_star_frame; apply ptsto32m'_out.
Qed.

Lemma NoDup_unapp1 : forall A (ls1 ls2 : list A),
  NoDup (ls1 ++ ls2)
  -> NoDup ls1.
  induction ls1; inversion 1; simpl in *; intuition; subst; constructor.
  intro; apply H2.
  apply in_or_app; auto.
  eauto.
Qed.

Lemma ptsto32m'_shift_base' : forall p n ls offset,
  (n <= offset)%nat
  -> ptsto32m' nil p offset ls
  ===> ptsto32m' nil (p ^+ $(n)) (offset - n) ls.
Proof.
  induction ls.

  intros; apply Himp_refl.

  unfold ptsto32m'; fold ptsto32m'.
  intros.
  intro; apply himp_star_frame.
  apply Himp_refl'; f_equal.
  rewrite <- wplus_assoc.
  rewrite <- natToW_plus.
  unfold natToW.
  repeat f_equal.
  omega.
  replace (4 + (offset - n)) with ((4 + offset) - n) by omega.
  apply IHls; omega.
Qed.

Lemma ptsto32m_shift_base' : forall p n ls offset,
  (n <= offset)%nat
  -> ptsto32m nil p offset ls
  ===> ptsto32m nil (p ^+ $(n)) (offset - n) ls.
Proof.
  intros; eapply Himp_trans.
  apply ptsto32m_ptsto32m'_himp.
  eapply Himp_trans.
  apply ptsto32m'_shift_base'.
  2: apply ptsto32m'_out.
  auto.
Qed.

Theorem prelude_out : forall ns ns' vs avail p,
  (length ns' <= avail)%nat
  -> locals (ns ++ ns') vs (avail - length ns') p
  ===> locals ns vs avail p.
Proof.
  unfold locals; intros.
  eapply Himp_trans; [ apply heq_star_assoc | ].
  apply himp_star_pure_c; intro Hboth.
  eapply Himp_trans; [ | apply heq_star_assoc ].
  apply himp_star_pure_cc.
  eapply NoDup_unapp1; eauto.
  unfold array.
  eapply Himp_trans.
  eapply himp_star_frame.
  apply ptsto32m_split.
  apply Himp_refl.
  eapply Himp_trans; [ apply heq_star_assoc | ].
  apply himp_star_frame; [ apply Himp_refl | ].
  eapply Himp_trans; [ | apply allocated_join ].
  2: eassumption.
  apply himp_star_frame.
  eapply Himp_trans; [ apply ptsto32m_allocated | ].
  apply allocated_shift_base.
  words.
  apply length_toArray.
  apply allocated_shift_base.
  rewrite app_length; words.
  auto.
Qed.

Lemma toArray_sel : forall x V V' ns',
  In x ns'
  -> toArray ns' V' = toArray ns' V
  -> sel V' x = sel V x.
  unfold toArray; induction ns'; simpl; intuition.
  subst.
  injection H0; intros.
  assumption.
  injection H0.
  auto.
Qed.
