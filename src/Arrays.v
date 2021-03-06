Require Import List.
Require Import Nomega NArith Word PropX PropXTac Memory SepIL IL.

Require Import sep.Array Allocated.

Lemma updN_length : forall ls a v,
  length (updN ls a v) = length ls.
  induction ls; simpl; intuition.
  destruct a0; simpl; auto.
Qed.

Lemma upd_length : forall ls a v,
  length (upd ls a v) = length ls.
  intros; apply updN_length.
Qed.

Hint Resolve upd_length updN_length.
Hint Rewrite upd_length updN_length : sepFormula.

Inductive containsArray : HProp -> list W -> Prop :=
| CABase : forall ls p, containsArray (array ls p) ls
| CALeft : forall P Q ls, containsArray P ls
  -> containsArray (ST.star P Q) ls
| CARight : forall P Q ls, containsArray Q ls
  -> containsArray (ST.star P Q) ls
| CAUpd : forall P ls a v, containsArray P (upd ls a v)
  -> containsArray P ls.

Hint Constructors containsArray.

Theorem containsArray_bound' : forall cs P stn ls,
  containsArray P ls
  -> forall st, interp cs (P stn st)
    -> (length ls < pow2 32)%nat.
  induction 1; intros.
  eapply array_bound; eauto.
  propxFo; eauto.
  propxFo; eauto.
  rewrite upd_length in *; eauto.
Qed.

Theorem containsArray_bound : forall cs P stn ls st,
  interp cs (![P] (stn, st))
  -> containsArray P ls
  -> (length ls < pow2 32)%nat.
  rewrite sepFormula_eq; intros; eapply containsArray_bound'; eauto.
Qed.

Hint Resolve containsArray_bound.

Theorem containsArray_goodSize : forall cs P stn ls st,
  interp cs (![P] (stn, st))
  -> containsArray P ls
  -> goodSize (length ls).
  intros; unfold goodSize.
  apply Nlt_in.
  rewrite Npow2_nat.
  rewrite Nat2N.id.
  eapply containsArray_bound; eauto.
Qed.

Hint Resolve containsArray_goodSize.

Lemma bound_N_nat : forall n,
  (n < pow2 32)%nat
  -> (N.of_nat n < Npow2 32)%N.
  intros; apply Nlt_in; rewrite Npow2_nat; repeat rewrite Nat2N.id; assumption.
Qed.

Hint Resolve bound_N_nat.

Lemma sel_selN : forall ls (a : nat),
  goodSize a
  -> sel ls (natToW a) = selN ls a.
  unfold sel; intros; rewrite wordToNat_natToWord_idempotent; auto.
Qed.

Lemma upd_updN : forall ls (a : nat) v,
  goodSize a
  -> upd ls (natToW a) v = updN ls a v.
  unfold upd; intros; rewrite wordToNat_natToWord_idempotent; auto.
Qed.

Lemma pow2_pos : forall sz, (0 < pow2 sz)%nat.
  induction sz; simpl; intuition.
Qed.

Hint Immediate pow2_pos.

Hint Extern 1 (_ < _)%nat => omega.

Hint Rewrite roundTrip_0 roundTrip_1 wordToNat_natToWord_idempotent using assumption : Arr.

Section next.
  Hint Rewrite wordToN_nat Npow2_nat : N.

  Lemma next : forall sz (w : word (S sz)) bound,
    w < bound
    -> wordToNat w + 1 = wordToNat (w ^+ $1).
    intros; rewrite wplus_alt; unfold wplusN, wordBinN.
    autorewrite with Arr.
    symmetry; apply wordToNat_natToWord_idempotent.
    apply Nlt_out in H; apply Nlt_in.
    autorewrite with N in *.
    specialize (wordToNat_bound bound).
    omega.
  Qed.
End next.

Hint Resolve next.

Lemma updN_app : forall b v a,
  Array.updN (a ++ b) (Datatypes.length a) v
  = a ++ Array.updN b 0 v.
  induction a; simpl; intuition congruence.
Qed.

Hint Rewrite updN_app : Arr.

Lemma upd_app : forall a b v,
  goodSize (length a)
  -> Array.upd (a ++ b) (natToW (length a)) v
  = a ++ Array.upd b (natToW 0) v.
  unfold Array.upd; intros; autorewrite with Arr; auto.
Qed.

Hint Rewrite app_length using solve [ auto ] : Arr.

Section goodSize_wordToNat.
  Hint Rewrite wordToN_nat Npow2_nat : N.

  Lemma goodSize_wordToNat : forall (w : W),
    goodSize (wordToNat w).
    intros; specialize (wordToNat_bound w); intros; unfold goodSize.
    unfold W in *; generalize dependent 32; intros; nomega.
  Qed.
End goodSize_wordToNat.

Hint Resolve goodSize_wordToNat.

Lemma upd_app' : forall a b v w,
  length a = wordToNat w
  -> Array.upd (a ++ b) w v
  = a ++ Array.upd b (natToW 0) v.
  intros; assert (natToWord 32 (length a) = natToWord 32 (wordToNat w)) by congruence;
    rewrite natToWord_wordToNat in *; subst; apply upd_app.
  rewrite H; auto.
Qed.

Hint Rewrite upd_app' using assumption : Arr.

Lemma goodSize_plus_l : forall n m,
  goodSize (n + m)
  -> goodSize n.
  unfold goodSize; generalize (Npow2 32); intros; nomega.
Qed.

Lemma goodSize_plus_r : forall n m,
  goodSize (n + m)
  -> goodSize m.
  unfold goodSize; generalize (Npow2 32); intros; nomega.
Qed.

Hint Immediate goodSize_plus_l goodSize_plus_r.

Lemma goodSize_S : forall n,
  goodSize (S n)
  -> goodSize n.
  unfold goodSize; generalize (Npow2 32); intros; nomega.
Qed.

Hint Immediate goodSize_S.

Lemma selN_middle : forall w ws' ws,
  goodSize (length ws)
  -> Array.selN (ws ++ w :: ws') (length ws) = w.
  induction ws; simpl; intuition.
Qed.

Hint Rewrite selN_middle using solve [ auto ] : Arr.

Lemma sel_middle : forall ws w ws',
  goodSize (length ws)
  -> Array.sel (ws ++ w :: ws') (natToW (length ws)) = w.
  unfold Array.sel; intros; autorewrite with Arr; reflexivity.
Qed.

Hint Rewrite sel_middle using solve [ auto ] : Arr.

Theorem pf_list_simpl : forall A c (a : list A) b,
  (a ++ b :: nil) ++ c = a ++ b :: c.
Proof.
  intros. rewrite app_ass. simpl. reflexivity.
Qed.

Hint Rewrite natToWord_wordToNat pf_list_simpl : Arr.
Hint Rewrite <- plus_n_O : Arr.

Lemma sel_middle' : forall ws w ws' n,
  length ws = wordToNat n  
  -> Array.sel (ws ++ w :: ws') n = w.
  intros; assert (natToWord 32 (length ws) = natToWord 32 (wordToNat n)) by congruence;
    autorewrite with Arr in *; subst.
  rewrite H; autorewrite with Arr.
  apply sel_middle.
  rewrite H; apply goodSize_wordToNat.
Qed.

Hint Rewrite sel_middle' using assumption : Arr.

Lemma upd0 : forall w ws v,
  Array.upd (w :: ws) (natToW 0) v = v :: ws.
  intros; unfold Array.upd; autorewrite with Arr; reflexivity.
Qed.

Hint Rewrite upd0 natToWord_wordToNat : Arr.
Hint Rewrite <- plus_n_O : Arr.

Require Import Arith.

Lemma le_wordToN : forall (n : nat) (w w' : W),
  w' <= w
  -> w' = natToW n
  -> goodSize n
  -> (n <= wordToNat w)%nat.
  intros; subst.
  destruct (le_lt_dec n (wordToNat w)); auto.
  elimtype False; apply H; clear H.
  red.
  repeat rewrite wordToN_nat.
  rewrite wordToNat_natToWord_idempotent by auto.
  clear H1; nomega.
Qed.

Hint Resolve le_wordToN.

Hint Rewrite wordToN_nat wordToNat_natToWord_idempotent using assumption : N.

Theorem lt_goodSize : forall n m,
  (n < m)%nat
  -> goodSize n
  -> goodSize m
  -> natToW n < natToW m.
  unfold goodSize, natToW, W; generalize 32; intros; nomega.
Qed.

Theorem goodSize_weaken : forall n m,
  goodSize n
  -> (m <= n)%nat
  -> goodSize m.
  unfold goodSize; generalize 32; intros; nomega.
Qed.

Hint Resolve lt_goodSize.

Hint Extern 1 (_ <= _)%nat => omega.

Theorem wle_goodSize : forall n m,
  natToW n <= natToW m
  -> goodSize n
  -> goodSize m
  -> (n <= m)%nat.
  intros.
  destruct (le_lt_dec n m); auto.
  elimtype False.
  apply H.
  apply Nlt_in.
  autorewrite with N.
  auto.
Qed.

Fixpoint arrayImplies (f : nat -> option W) (ws : list W) (offset : nat) : Prop :=
  match ws with
    | nil => True
    | w :: ws' => f offset = Some w /\ arrayImplies f ws' (4 + offset)
  end.

Lemma implies_inj_and : forall pc state (specs : codeSpec pc state) G P Q,
  valid specs G [| P |]%PropX
  -> valid specs G [| Q |]%PropX
  -> valid specs G [| P /\ Q |]%PropX.
  intros.
  eapply Imply_E; [ | eassumption ].
  apply Imply_I.
  eapply Imply_E; [ | eapply valid_weaken; try apply H; hnf; simpl; tauto ].
  apply Imply_I.
  eapply Inj_E; [ apply Env; simpl; eauto | intro ].
  eapply Inj_E; [ apply Env; simpl; left; eauto | intro ].
  apply Inj_I; tauto.
Qed.

Lemma arrayImplies_weaken : forall f f',
  (forall n v, f n = Some v -> f' n = Some v)
  -> forall ws offset,
    arrayImplies f ws offset
    -> arrayImplies f' ws offset.
  induction ws; simpl; intuition.
Qed.

Lemma inj_imply : forall pc state (specs : codeSpec pc state) (P Q : Prop),
  (P -> Q)
  -> interp specs ([| P |] ---> [| Q |])%PropX.
  intros; apply Imply_I; eapply Inj_E; [ apply Env; simpl; eauto | ];
    intro; apply Inj_I; tauto.
Qed.

Local Opaque mult.

Lemma ptsto32m'_implies : forall specs stn p ws offset m,
  interp specs (ptsto32m' _ p offset ws stn m --->
    [| arrayImplies (fun n => smem_read_word stn (p ^+ $(n)) m) ws offset |])%PropX.
Proof.
  induction ws; unfold ptsto32m', arrayImplies; fold ptsto32m'; fold arrayImplies; intuition.
  apply Imply_I; apply Inj_I; constructor.
  unfold starB, star; apply Imply_I.
  unfold STK.istar.
  eapply Exists_E; [ apply Env; hnf; eauto | cbv beta; intro ].
  eapply Exists_E; [ apply Env; hnf; left; eauto | cbv beta; intro ].
  apply implies_inj_and.
  unfold ptsto32.
  eapply Inj_E; [ eapply And_E1; apply Env; hnf; eauto | intro ].
  eapply Inj_E; [ eapply And_E1; eapply And_E2; apply Env; hnf; eauto | intro ].
  apply Inj_I.
  eapply MSMF.split_multi_read. eassumption. destruct H0. eapply H0.
  eapply Inj_E; [ eapply And_E1; apply Env; hnf; eauto | intro ].
  eapply Imply_E; [ apply interp_weaken; apply inj_imply;
    apply (arrayImplies_weaken (fun n => smem_read_word stn (p ^+ $ (n)) B0)) | ].
  eapply split_comm in H.
  intros; eapply MSMF.split_multi_read; eauto. 
  eapply Imply_E.
  eauto.
  eapply And_E2; eapply And_E2; apply Env; hnf; eauto.
Qed.

Theorem ptsto32m'_in : forall a vs offset,
  ptsto32m _ a offset vs ===> ptsto32m' _ a offset vs.
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
  etransitivity. eapply STK.himp_star_emp_c.  apply STK.himp_star_comm.

  apply STK.himp_star_frame; [ reflexivity | ]. eapply IHvs.
Qed.

Lemma ptsto32m_implies : forall specs stn m p ws offset,
  interp specs (ptsto32m _ p offset ws stn m --->
    [| arrayImplies (fun n => smem_read_word stn (p ^+ $(n)) m) ws offset |])%PropX.
  intros; eapply Imply_trans; apply ptsto32m'_implies || apply ptsto32m'_in.
Qed.

Lemma array_implies : forall specs stn m ws p,
  interp specs (array ws p stn m --->
    [| arrayImplies (fun n => smem_read_word stn (p ^+ $(n)) m) ws 0 |])%PropX.
  intros; apply ptsto32m_implies.
Qed.

Lemma arrayImplies_equal : forall stn p m m1 m2 m1' m2',
     split m m1 m2
  -> split m m1' m2'
  -> forall ws ws' offset,
    arrayImplies (fun n => smem_read_word stn (p ^+ $(n)) m1) ws offset
    -> arrayImplies (fun n => smem_read_word stn (p ^+ $(n)) m1') ws' offset
    -> length ws' = length ws
    -> ws' = ws.
Proof.
  induction ws; destruct ws'; unfold length, arrayImplies; fold length; fold arrayImplies; intuition.
  f_equal; eauto.
  unfold smem_read_word in *.
  eapply MSMF.split_multi_read in H0; [ | eauto ].
  eapply MSMF.split_multi_read in H; [ | eauto ].
  congruence.
Qed.

Lemma array_equals : forall specs stn st ws p fr ws' fr',
  interp specs (![array ws p * fr] (stn, st))
  -> interp specs (![array ws' p * fr'] (stn, st) --->
    [| length ws' = length ws -> ws' = ws |])%PropX.
Proof.
  rewrite sepFormula_eq; unfold sepFormula_def, starB, star, STK.istar; simpl; intros.
  propxFo.
  eapply Imply_sound in H; [ | apply array_implies ].
  apply Inj_sound in H.
  apply Imply_I.
  eapply Exists_E; [ apply Env; simpl; eauto | cbv beta; intro ].
  eapply Exists_E; [ apply Env; simpl; left; eauto | cbv beta; intro ].
  eapply Inj_E; [ eapply And_E1; apply Env; simpl; eauto | cbv beta; intro ].
  eapply Imply_E.
  eapply Imply_trans'.
  apply interp_weaken; apply array_implies.
  apply Imply_I.
  eapply Inj_E; [ apply Env; hnf; eauto | cbv beta; intro ].
  apply Inj_I; intro.
  eauto using arrayImplies_equal.
  eapply And_E1; eapply And_E2; apply Env; simpl; eauto.
Qed.

Lemma imply_and : forall pc state (specs : codeSpec pc state) (P : Prop) Q R,
  (P -> interp specs (Q ---> R)%PropX)
  -> interp specs (Q /\ [| P |] ---> R)%PropX.
  intros; apply Imply_I.
  eapply Inj_E; [ eapply And_E2; apply Env; simpl; eauto | ]; intuition.
  eapply Imply_E; eauto.
  eapply And_E1; apply Env; simpl; eauto.
Qed.

Lemma smem_read_correctx'' : forall cs base stn ws offset i m,
  (i < length ws)%nat
  -> interp cs (ptsto32m' _ base (offset * 4) ws stn m
    ---> [| smem_read_word stn (base ^+ $((offset + i) * 4)) m = Some (selN ws i) |])%PropX.
Proof.
  induction ws.

  { simpl length.
    intros.
    elimtype False.
    nomega. }

  simpl length.
  unfold ptsto32m'.
  fold ptsto32m'.
  intros.
  destruct i; simpl selN.
  replace (offset + 0) with offset by omega.
  unfold starB, star, STK.istar.
  apply Imply_I.
  eapply Exists_E; [ apply Env; hnf; eauto | cbv beta; intro ].
  eapply Exists_E; [ apply Env; hnf; left; eauto | cbv beta; intro ].
  unfold ptsto32.
  eapply Inj_E; [ eapply And_E1; apply Env; hnf; eauto | intro ].
  eapply Inj_E; [ eapply And_E1; eapply And_E2; apply Env; hnf; eauto | intro ].
  apply Inj_I.
  eapply MSMF.split_multi_read; eauto.
  tauto.

  unfold starB, star, STK.istar.
  apply Imply_I.
  eapply Exists_E; [ apply Env; hnf; eauto | cbv beta; intro ].
  eapply Exists_E; [ apply Env; hnf; left; eauto | cbv beta; intro ].
  replace (4 + offset * 4) with (S offset * 4) by omega.
  replace (offset + S i) with (S offset + i) by omega.
  eapply Imply_E.
  eapply Imply_trans'.
  apply interp_weaken; apply IHws.
  instantiate (1 := i); omega.
  instantiate (1 := B0).
  eapply Inj_E; [ eapply And_E1; apply Env; hnf; eauto | intro ].
  apply interp_weaken; apply inj_imply.
  instantiate (1 := S offset).
  intros.
  eapply split_comm in H0.
  eapply MSMF.split_multi_read; eauto.
  do 2 eapply And_E2; apply Env; hnf; eauto.
Qed.

Lemma array_boundx' : forall cs base stn ws m i,
  (0 < i < length ws)%nat
  -> base ^+ $(i * 4) = base
  -> interp cs (ptsto32m' _ base 0 ws stn m ---> [| False |])%PropX.
Proof.
  destruct ws; simpl length; intros.

  { elimtype False; omega. }

  { propxFo.
    destruct i; try omega.
    simpl in H1.
    unfold starB, star, STK.istar.
    apply Imply_I.
    eapply Exists_E; [ apply Env; simpl; eauto | cbv beta; intro ].
    eapply Exists_E; [ apply Env; simpl; left; eauto | cbv beta; intro ].
    generalize (@smem_read_correctx'' cs base stn ws 1 i B0).
    hnf.
    change (1 + i) with (S i).
    rewrite H0.
    intro Hlem.
    assert (i < length ws)%nat by omega; intuition.
    eapply Inj_E.
    unfold ptsto32.
    eapply And_E1; eapply And_E2; apply Env; hnf; eauto.
    rewrite wplus_comm.
    rewrite wplus_unit.
    intuition.
    eapply Inj_E; [ eapply And_E1; apply Env; hnf; eauto | intro ].
    eapply Inj_E.
    eapply Imply_E.
    eauto.
    do 2 eapply And_E2; apply Env; hnf; eauto.
    intro.
    apply Inj_I.
    eapply smem_read_word_disjoint; eauto. }
Qed.

Lemma array_boundx : forall cs ws base stn m,
  interp cs (array ws base stn m ---> [| length ws < pow2 32 |]%nat)%PropX.
Proof.
  intros.
  destruct (lt_dec (length ws) (pow2 32)); auto.
  apply Imply_I; apply Inj_I; auto.
  eapply Imply_trans with [| False |]%PropX; [ | apply inj_imply; tauto ].
  eapply Imply_trans; try apply ptsto32m'_in.
  apply array_boundx' with (pow2 30).
  split.
  unfold pow2; omega.
  specialize (@pow2_monotone 30 32).
  omega.
  change (pow2 30 * 4) with (pow2 30 * pow2 2).
  rewrite pow2_mult.
  simpl plus.
  clear.
  rewrite wplus_alt.
  unfold wplusN, wordBinN.
  rewrite natToWord_pow2.
  rewrite roundTrip_0.
  rewrite plus_0_r.
  apply natToWord_wordToNat.
Qed.

Theorem containsArray_boundx' : forall cs P stn ls,
  containsArray P ls
  -> forall st, interp cs (P stn st ---> [|length ls < pow2 32|]%nat)%PropX.
Proof.
  induction 1; intros.
  { eapply array_boundx; eauto. }

  { unfold star, STK.istar.
    apply Imply_I.
    eapply Exists_E; [ apply Env; simpl; eauto | cbv beta; intro ].
    eapply Exists_E; [ apply Env; simpl; left; eauto | cbv beta; intro ].
    eapply Imply_E; eauto.
    eapply And_E1; eapply And_E2; apply Env; simpl; eauto. }

  { unfold star, STK.istar.
    apply Imply_I.
    eapply Exists_E; [ apply Env; simpl; eauto | cbv beta; intro ].
    eapply Exists_E; [ apply Env; simpl; left; eauto | cbv beta; intro ].
    eapply Imply_E; eauto.
    do 2 eapply And_E2; apply Env; simpl; eauto. }

  { rewrite upd_length in *; eauto. }
Qed.

Theorem containsArray_boundx : forall cs P stn ls st,
  containsArray P ls
  -> interp cs (![P] (stn, st) ---> [| length ls < pow2 32 |]%nat)%PropX.
Proof.
  rewrite sepFormula_eq; intros; unfold sepFormula_def, fst, snd;
    auto using containsArray_boundx'.
Qed.

Local Hint Resolve containsArray_boundx.

Theorem containsArray_goodSizex' : forall cs P stn ls st,
  containsArray P ls
  -> interp cs (P stn st ---> [| goodSize (length ls) |])%PropX.
  intros; unfold goodSize.
  eapply Imply_trans.
  eapply containsArray_boundx'; eauto.
  apply inj_imply; intro.
  apply Nlt_in.
  rewrite Npow2_nat.
  rewrite Nat2N.id.
  assumption.
Qed.

Theorem containsArray_goodSizex : forall cs P stn ls st,
  containsArray P ls
  -> interp cs (![P] (stn, st) ---> [| goodSize (length ls) |])%PropX.
  intros; unfold goodSize.
  eapply Imply_trans.
  eapply containsArray_boundx; eauto.
  apply inj_imply; intro.
  apply Nlt_in.
  rewrite Npow2_nat.
  rewrite Nat2N.id.
  assumption.
Qed.

Hint Resolve containsArray_goodSizex.

Theorem le_goodSize : forall n m,
  (n <= m)%nat
  -> goodSize n
  -> goodSize m
  -> natToW n <= natToW m.
  unfold goodSize, natToW, W; generalize 32; intros; nomega.
Qed.

Theorem lt_goodSize' : forall n m,
  natToW n < natToW m
  -> goodSize n
  -> goodSize m
  -> (n < m)%nat.
  unfold goodSize, natToW, W; generalize 32; intros.
  pre_nomega.
  repeat rewrite wordToNat_natToWord_idempotent in H by nomega.
  assumption.
Qed.

Global Opaque goodSize.
