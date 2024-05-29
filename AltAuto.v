(** * AltAuto: A Streamlined Treatment of Automation *)

(** So far, we've been doing all our proofs using just a small
    handful of Coq's tactics and completely ignoring its powerful
    facilities for constructing parts of proofs automatically. Getting
    used to them will take some work -- Coq's automation is a power
    tool -- but it will allow us to scale up our efforts to more
    complex definitions and more interesting properties without
    becoming overwhelmed by boring, repetitive, low-level details.

    In this chapter, we'll learn about

    - _tacticals_, which allow tactics to be combined;

    - new tactics that make dealing with hypothesis names less fussy
      and more maintainable;

    - _automatic solvers_ that can prove limited classes of theorems
      without any human assistance;

    - _proof search_ with the [auto] tactic; and

    - the _Ltac_ language for writing tactics.

    These features enable startlingly short proofs. Used properly,
    they can also make proofs more maintainable and robust to changes
    in underlying definitions.

    This chapter is an alternative to the combination of [Imp]
    and [Auto], which cover roughly the same material about
    automation, but in the context of programming language metatheory.
    A deeper treatment of [auto] can be found in the [UseAuto]
    chapter in _Programming Language Foundations_.  *)

Set Warnings "-notation-overridden,-parsing,-deprecated-hint-without-locality,-deprecated-syntactic-definition,-deprecated]".
From Coq Require Import Arith List.
From LF Require Import IndProp.

(** As a simple illustration of the benefits of automation,
    let's consider another problem on regular expressions, which we
    formalized in [IndProp].  A given set of strings can be
    denoted by many different regular expressions.  For example, [App
    EmptyString re] matches exactly the same strings as [re].  We can
    write a function that "optimizes" any regular expression into a
    potentially simpler one by applying this fact throughout the r.e.
    (Note that, for simplicity, the function does not optimize
    expressions that arise as the result of other optimizations.) *)

Fixpoint re_opt_e {T:Type} (re: reg_exp T) : reg_exp T :=
  match re with
  | App EmptyStr re2 => re_opt_e re2
  | App re1 re2 => App (re_opt_e re1) (re_opt_e re2)
  | Union re1 re2 => Union (re_opt_e re1) (re_opt_e re2)
  | Star re => Star (re_opt_e re)
  | _ => re
  end.

(** We would like to show the equivalence of re's with their
    "optimized" form.  One direction of this equivalence looks like
    this (the other is similar).  *)
Check reg_exp_ind.

Lemma re_opt_e_match : forall T (re: reg_exp T) s,
  s =~ re -> s =~ re_opt_e re.
Proof.
  intros T re s M.
  induction M
    as [| x'
        | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
        | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
        | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2].
  - (* MEmpty *) simpl. apply MEmpty.
  - (* MChar *) simpl. apply MChar.
  - (* MApp *) simpl.
    destruct re1.
    + apply MApp.
      * apply IH1.
      * apply IH2.
    + inversion Hmatch1. simpl. apply IH2.
    + apply MApp.
      * apply IH1.
      * apply IH2.
    + apply MApp.
      * apply IH1.
      * apply IH2.
    + apply MApp.
      * apply IH1.
      * apply IH2.
    + apply MApp.
      * apply IH1.
      * apply IH2.
  - (* MUnionL *) simpl. apply MUnionL. apply IH.
  - (* MUnionR *) simpl. apply MUnionR. apply IH.
  - (* MStar0 *) simpl. apply MStar0.
  - (* MStarApp *) simpl. apply MStarApp.
    * apply IH1.
    * apply IH2.
Qed.

(** The amount of repetition in that proof is annoying.  And if
    we wanted to extend the optimization function to handle other,
    similar, rewriting opportunities, it would start to be a real
    problem. We can streamline the proof with _tacticals_, which we
    turn to, next. *)

(* ################################################################# *)
(** * Tacticals *)

(** _Tacticals_ are tactics that take other tactics as arguments --
    "higher-order tactics," if you will.  *)

(* ================================================================= *)
(** ** The [try] Tactical *)

(** If [T] is a tactic, then [try T] is a tactic that is just like [T]
    except that, if [T] fails, [try T] _successfully_ does nothing at
    all instead of failing. *)

Theorem silly1 : forall n, 1 + n = S n.
Proof. try reflexivity. (* this just does [reflexivity] *) Qed.

Theorem silly2 : forall (P : Prop), P -> P.
Proof.
  intros P HP.
  Fail reflexivity.
  try reflexivity. (* proof state is unchanged *)
  apply HP.
Qed.

(** There is no real reason to use [try] in completely manual
    proofs like these, but it is very useful for doing automated
    proofs in conjunction with the [;] tactical, which we show
    next. *)

(* ================================================================= *)
(** ** The Sequence Tactical [;] (Simple Form) *)

(** In its most common form, the sequence tactical, written with
    semicolon [;], takes two tactics as arguments.  The compound
    tactic [T; T'] first performs [T] and then performs [T'] on _each
    subgoal_ generated by [T]. *)

(** For example, consider the following trivial lemma: *)

Lemma simple_semi : forall n, (n + 1 =? 0) = false.
Proof.
  intros n.
  destruct n eqn:E.
    (* Leaves two subgoals, which are discharged identically...  *)
    - (* n=0 *) simpl. reflexivity.
    - (* n=Sn' *) simpl. reflexivity.
Qed.

(** We can simplify this proof using the [;] tactical: *)

Lemma simple_semi' : forall n, (n + 1 =? 0) = false.
Proof.
  intros n.
  (* [destruct] the current goal *)
  destruct n;
  (* then [simpl] each resulting subgoal *)
  simpl;
  (* and do [reflexivity] on each resulting subgoal *)
  reflexivity.
Qed.

(** Or even more tersely, [destruct] can do the [intro], and [simpl]
    can be omitted: *)

Lemma simple_semi'' : forall n, (n + 1 =? 0) = false.
Proof.
  destruct n; reflexivity.
Qed.

(** **** Exercise: 3 stars, standard (try_sequence) *)

(** Prove the following theorems using [try] and [;]. Like
    [simple_semi''] above, each proof script should be a sequence [t1;
    ...; tn.] of tactics, and there should be only one period in
    between [Proof.] and [Qed.]. Let's call that a "one shot"
    proof. *)

Theorem andb_eq_orb :
  forall (b c : bool),
  (andb b c = orb b c) ->
  b = c.
Proof.
  intros.
  destruct b; destruct c; try (discriminate H); try (reflexivity).
Qed.

Theorem add_assoc : forall n m p : nat,
    n + (m + p) = (n + m) + p.
Proof.
  intros;
    induction n;
    try (simpl; reflexivity);
    try(simpl; rewrite -> IHn; reflexivity).
Qed.

Fixpoint nonzeros (lst : list nat) :=
  match lst with
  | [] => []
  | 0 :: t => nonzeros t
  | h :: t => h :: nonzeros t
  end.

Lemma nonzeros_app : forall lst1 lst2 : list nat,
  nonzeros (lst1 ++ lst2) = (nonzeros lst1) ++ (nonzeros lst2).
Proof.
  intros; generalize dependent lst2; induction lst1 as [| h' t' IH'].
  - intros lst2; simpl; reflexivity.
  - intros lst2; destruct h' ;simpl; rewrite -> IH'; reflexivity.
Qed.

(** [] *)

(** Using [try] and [;] together, we can improve the proof about
    regular expression optimization. *)

Lemma re_opt_e_match' : forall T (re: reg_exp T) s,
  s =~ re -> s =~ re_opt_e re.
Proof.
  intros T re s M.
  induction M
    as [| x'
        | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
        | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
        | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2];
    (* Do the [simpl] for every case here: *)
    simpl.
  - (* MEmpty *) apply MEmpty.
  - (* MChar *) apply MChar.
  - (* MApp *)
    destruct re1;
    (* Most cases follow by the same formula.  Notice that [apply
       MApp] gives two subgoals: [try apply IH1] is run on _both_ of
       them and succeeds on the first but not the second; [apply IH2]
       is then run on this remaining goal. *)
    try (apply MApp; try apply IH1; apply IH2).
    (* The interesting case, on which [try...] does nothing, is when
       [re1 = EmptyStr]. In this case, we have to appeal to the fact
       that [re1] matches only the empty string: *)
    inversion Hmatch1. simpl. apply IH2.
  - (* MUnionL *) apply MUnionL. apply IH.
  - (* MUnionR *) apply MUnionR. apply IH.
  - (* MStar0 *) apply MStar0.
  - (* MStarApp *)  apply MStarApp. apply IH1.  apply IH2.
Qed.

(* ================================================================= *)
(** ** The Sequence Tactical [;] (Local Form) *)

(** The sequence tactical [;] also has a more general form than the
    simple [T; T'] we saw above.  If [T], [T1], ..., [Tn] are tactics,
    then

[[ T; [T1 | T2 | ... | Tn] ]]

    is a tactic that first performs [T] and then locally performs [T1]
    on the first subgoal generated by [T], locally performs [T2] on
    the second subgoal, etc.

    So [T; T'] is just special notation for the case when all of the
    [Ti]'s are the same tactic; i.e., [T; T'] is shorthand for:

      T; [T' | T' | ... | T']

    For example, the following proof makes it clear which tactics are
    used to solve the base case vs. the inductive case.
 *)

Theorem app_length : forall (X : Type) (lst1 lst2 : list X),
    length (lst1 ++ lst2) = (length lst1) + (length lst2).
Proof.
  intros; induction lst1;
    [reflexivity | simpl; rewrite IHlst1; reflexivity].
Qed.

(** The identity tactic [idtac] always succeeds without changing the
    proof state. We can use it to factor out [reflexivity] in the
    previous proof. *)

Theorem app_length' : forall (X : Type) (lst1 lst2 : list X),
    length (lst1 ++ lst2) = (length lst1) + (length lst2).
Proof.
  intros; induction lst1;
    [idtac | simpl; rewrite IHlst1];
    reflexivity.
Qed.

(** **** Exercise: 1 star, standard (notry_sequence) *)

(** Prove the following theorem with a one-shot proof, but this
    time, do not use [try]. *)

Theorem add_assoc' : forall n m p : nat,
    n + (m + p) = (n + m) + p.
Proof.
  intros;
  induction n; [simpl; reflexivity | simpl; rewrite -> IHn; reflexivity].
Qed.

(** [] *)

(** We can use the local form of the sequence tactical to give a
    slightly neater version of our optimization proof. Two lines
    change, as shown below with [<===]. *)

Lemma re_opt_e_match'' : forall T (re: reg_exp T) s,
  s =~ re -> s =~ re_opt_e re.
Proof.
  intros T re s M.
  induction M
    as [| x'
        | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
        | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
        | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2];
    (* Do the [simpl] for every case here: *)
    simpl.
  - (* MEmpty *) apply MEmpty.
  - (* MChar *) apply MChar.
  - (* MApp *)
    destruct re1;
    try (apply MApp; [apply IH1 | apply IH2]).  (* <=== *)
    inversion Hmatch1. simpl. apply IH2.
  - (* MUnionL *) apply MUnionL. apply IH.
  - (* MUnionR *) apply MUnionR. apply IH.
  - (* MStar0 *) apply MStar0.
  - (* MStarApp *)  apply MStarApp; [apply IH1 | apply IH2].  (* <=== *)
Qed.

(* ================================================================= *)
(** ** The [repeat] Tactical *)

(** The [repeat] tactical takes another tactic and keeps
    applying this tactic until it fails or stops making progress. Here
    is an example showing that [10] is in a long list: *)

Theorem In10 : In 10 [1;2;3;4;5;6;7;8;9;10].
Proof.
  repeat (try (left; reflexivity); right).
Qed.

(** The tactic [repeat T] never fails: if the tactic [T] doesn't apply
    to the original goal, then [repeat] still succeeds without
    changing the original goal (i.e., it repeats zero times). *)

Theorem In10' : In 10 [1;2;3;4;5;6;7;8;9;10].
Proof.
  repeat (left; reflexivity).
  repeat (right; try (left; reflexivity)).
Qed.

(** The tactic [repeat T] also does not have any upper bound on the
    number of times it applies [T].  If [T] is a tactic that always
    succeeds, then repeat [T] will loop forever (e.g., [repeat simpl]
    loops, since [simpl] always succeeds). Evaluation in Coq's term
    language, Gallina, is guaranteed to terminate, but tactic
    evaluation is not. This does not affect Coq's logical consistency,
    however, since the job of [repeat] and other tactics is to guide
    Coq in constructing proofs. If the construction process diverges,
    it simply means that we have failed to construct a proof, not that
    we have constructed an incorrect proof. *)

(** **** Exercise: 1 star, standard (ev100)

    Prove that 100 is even. Your proof script should be quite short. *)

Theorem ev100: ev 100.
Proof.
  repeat (apply ev_SS).
  apply ev_0.
Qed.

(** [] *)

(* ================================================================= *)
(** ** An Optimization Exercise  *)
(** **** Exercise: 4 stars, standard (re_opt) *)

(** Consider this more powerful version of the regular expression
    optimizer. *)

Fixpoint re_opt {T:Type} (re: reg_exp T) : reg_exp T :=
  match re with
  | App _ EmptySet => EmptySet
  | App EmptyStr re2 => re_opt re2
  | App re1 EmptyStr => re_opt re1
  | App re1 re2 => App (re_opt re1) (re_opt re2)
  | Union EmptySet re2 => re_opt re2
  | Union re1 EmptySet => re_opt re1
  | Union re1 re2 => Union (re_opt re1) (re_opt re2)
  | Star EmptySet => EmptyStr
  | Star EmptyStr => EmptyStr
  | Star re => Star (re_opt re)
  | EmptySet => EmptySet
  | EmptyStr => EmptyStr
  | Char x => Char x
  end.

Lemma re_opt_match : forall T (re: reg_exp T) s,
  s =~ re -> s =~ re_opt re.
Proof.
Proof.
  intros T re s M.
  induction M
    as [| x'
        | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
        | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
        | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2].
  - (* MEmpty *) simpl; apply MEmpty.
  - (* MChar *) simpl; apply MChar.
  - (* MApp *)
    simpl;
      destruct re1;
      [inversion IH1 | inversion IH1; simpl; destruct re2; apply IH2 | | | |];
      (destruct re2;
       [inversion IH2 | inversion IH2; rewrite app_nil_r; apply IH1 | | | | ];
       (apply MApp; [apply IH1 | apply IH2])).
  - (* MUnionL *)
    simpl;
      destruct re1;
      [inversion IH | | | | |];
      destruct re2; try apply MUnionL; apply IH.
  - (* MUnionR *)
    simpl;
      destruct re1;
      [apply IH | | | | |];
      (destruct re2; [inversion IH | | | | |]; apply MUnionR; apply IH).
 - (* MStar0 *)
   simpl;
     destruct re; try apply MEmpty; try apply MStar0.
 - (* MStarApp *)
   simpl;
    destruct re;
    [inversion IH1 | inversion IH1; inversion IH2; apply MEmpty | | | |];
    (apply star_app; [apply MStar1; apply IH1 | apply IH2]).
Qed.  

(* Do not modify the following line: *)
Definition manual_grade_for_re_opt : option (nat*string) := None.
(** [] *)

(* ################################################################# *)
(** * Tactics that Make Mentioning Names Unnecessary *)

(** So far we have been dependent on knowing the names of
    hypotheses.  For example, to prove the following simple theorem,
    we hardcode the name [HP]: *)

Theorem hyp_name : forall (P : Prop), P -> P.
Proof.
  intros P HP. apply HP.
Qed.

(** We took the trouble to invent a name for [HP], then we had
    to remember that name. If we later change the name in one place,
    we have to change it everywhere. Likewise, if we were to add new
    arguments to the theorem, we would have to adjust the [intros]
    list. That makes it challenging to maintain large proofs. So, Coq
    provides several tactics that make it possible to write proof
    scripts that do not hardcode names. *)

(* ================================================================= *)
(** ** The [assumption] tactic *)

(** The [assumption] tactic is useful to streamline the proof
    above. It looks through the hypotheses and, if it finds the goal
    as one them, it uses that to finish the proof. *)

Theorem no_hyp_name : forall (P : Prop), P -> P.
Proof.
  intros. assumption.
Qed.

(** Some might argue to the contrary that hypothesis names
    improve self-documention of proof scripts. Maybe they do,
    sometimes. But in the case of the two proofs above, the first
    mentions unnecessary detail, whereas the second could be
    paraphrased simply as "the conclusion follows from the
    assumptions."

    Anyway, unlike informal (good) mathematical proofs, Coq proof
    scripts are generally not that illuminating to readers. Worries
    about rich, self-documenting names for hypotheses might be
    misplaced. *)

(* ================================================================= *)
(** ** The [contradiction] tactic *)

(** The [contradiction] tactic handles some ad hoc situations where a
    hypothesis contains [False], or two hypotheses derive [False]. *)

Theorem false_assumed : False -> 0 = 1.
Proof.
  intros H. destruct H.
Qed.

Theorem false_assumed' : False -> 0 = 1.
Proof.
  intros. contradiction.
Qed.

Theorem contras : forall (P : Prop), P -> ~P -> 0 = 1.
Proof.
  intros P HP HNP. exfalso. apply HNP. apply HP.
Qed.

Theorem contras' : forall (P : Prop), P -> ~P -> 0 = 1.
Proof.
  intros. contradiction.
Qed.

(* ================================================================= *)
(** ** The [subst] tactic *)

(** The [subst] tactic substitutes away an identifier, replacing
    it everywhere and eliminating it from the context. That helps
    us to avoid naming hypotheses in [rewrite]s. *)

Theorem many_eq : forall (n m o p : nat),
  n = m ->
  o = p ->
  [n; o] = [m; p].
Proof.
  intros n m o p Hnm Hop. rewrite Hnm. rewrite Hop. reflexivity.
Qed.

Theorem many_eq' : forall (n m o p : nat),
  n = m ->
  o = p ->
  [n; o] = [m; p].
Proof.
  intros. subst. reflexivity.
Qed.

(** Actually there are two forms of this tactic.

     - [subst x] finds an assumption [x = e] or [e = x] in the
       context, replaces [x] with [e] throughout the context and
       current goal, and removes the assumption from the context.

     - [subst] substitutes away _all_ assumptions of the form [x = e]
       or [e = x]. *)

(* ================================================================= *)
(** ** The [constructor] tactic *)

(** The [constructor] tactic tries to find a constructor [c] (from the
    appropriate [Inductive] definition in the current environment)
    that can be applied to solve the current goal. *)

Check ev_0 : ev 0.
Check ev_SS : forall n : nat, ev n -> ev (S (S n)).

Example constructor_example: forall (n:nat),
    ev (n + n).
Proof.
  induction n; simpl.
  - constructor. (* applies ev_0 *)
  - rewrite add_comm. simpl. constructor. (* applies ev_SS *)
    assumption.
Qed.

(** Warning: if more than one constructor can apply,
    [constructor] picks the first one, in the order in which they were
    defined in the [Inductive] definition. That might not be the one
    you want. *)

(* ################################################################# *)
(** * Automatic Solvers *)

(** Coq has several special-purpose tactics that can solve
    certain kinds of goals in a completely automated way. These
    tactics are based on sophisticated algorithms developed for
    verification in specific mathematical or logical domains.

    Some automatic solvers are _decision procedures_, which are
    algorithms that always terminate, and always give a correct
    answer. Here, that means that they always find a correct proof, or
    correctly determine that the goal is invalid.  Other automatic
    solvers are _incomplete_: they might fail to find a proof of a
    valid goal. *)

(* ================================================================= *)
(** ** Linear Integer Arithmetic: The [lia] Tactic *)

(** The [lia] tactic implements a decision procedure for integer
    linear arithmetic, a subset of propositional logic and arithmetic.
    As input it accepts goals constructed as follows:

      - variables and constants of type [nat], [Z], and other integer
        types;

      - arithmetic operators [+], [-], [*], and [^];

      - equality [=] and ordering [<], [>], [<=], [>=]; and

      - the logical connectives [/\], [\/], [~], [->], and [<->]; and
        constants [True] and [False].

    _Linear_ goals involve (in)equalities over expressions of the form
    [c1 * x1 + ... + cn * xn], where [ci] are constants and [xi] are
    variables.

    - For linear goals, [lia] will either solve the goal or fail,
      meaning that the goal is actually invalid.

    - For non-linear goals, [lia] will also either solve the goal or
      fail. But in this case, the failure does not necessarily mean
      that the goal is invalid -- it might just be beyond [lia]'s
      reach to prove because of non-linearity.

    Also, [lia] will do [intros] as necessary. *)

From Coq Require Import Lia.

Theorem lia_succeed1 : forall (n : nat),
  n > 0 -> n * 2 > n.
Proof. lia. Qed.

Theorem lia_succeed2 : forall (n m : nat),
    n * m = m * n.
Proof.
  lia. (* solvable though non-linear *)
Qed.

Theorem lia_fail1 : 0 = 1.
Proof.
  Fail lia. (* goal is invalid *)
Abort.

Theorem lia_fail2 : forall (n : nat),
    n >= 1 -> 2 ^ n = 2 * 2 ^ (n - 1).
Proof.
  Fail lia. (*goal is non-linear, valid, but unsolvable by lia *)
Abort.

(** There are other tactics that can solve arithmetic goals.  The
    [ring] and [field] tactics, for example, can solve equations over
    the algebraic structures of _rings_ and _fields_, from which the
    tactics get their names. These tactics do not do [intros]. *)

Require Import Ring.

Theorem mult_comm : forall (n m : nat),
    n * m = m * n.
Proof.
  intros n m. ring.
Qed.

(* ================================================================= *)
(** ** Equalities: The [congruence] Tactic *)

(** The [lia] tactic makes use of facts about addition and
    multiplication to prove equalities. A more basic way of treating
    such formulas is to regard every function appearing in them as
    a black box: nothing is known about the function's behavior.
    Based on the properties of equality itself, it is still possible
    to prove some formulas. For example, [y = f x -> g y = g (f x)],
    even if we know nothing about [f] or [g]:
 *)

Theorem eq_example1 :
  forall (A B C : Type) (f : A -> B) (g : B -> C) (x : A) (y : B),
    y = f x -> g y = g (f x).
Proof.
  intros. rewrite H. reflexivity.
Qed.

(** The essential properties of equality are that it is:

    - reflexive

    - symmetric

    - transitive

    - a _congruence_: it respects function and predicate
      application. *)

(** It is that congruence property that we're using when we
    [rewrite] in the proof above: if [a = b] then [f a = f b].  (The
    [ProofObjects] chapter explores this idea further under the
    name "Leibniz equality".) *)

(** The [congruence] tactic is a decision procedure for equality with
    uninterpreted functions and other symbols.  *)

Theorem eq_example1' :
  forall (A B C : Type) (f : A -> B) (g : B -> C) (x : A) (y : B),
    y = f x -> g y = g (f x).
Proof.
  congruence.
Qed.

(** The [congruence] tactic is able to work with constructors,
    even taking advantage of their injectivity and distinctness. *)

Theorem eq_example2 : forall (n m o p : nat),
    n = m ->
    o = p ->
    (n, o) = (m, p).
Proof.
  congruence.
Qed.

Theorem eq_example3 : forall (X : Type) (h : X) (t : list X),
    [] <> h :: t.
Proof.
  congruence.
Qed.

(* ================================================================= *)
(** ** Propositions: The [intuition] Tactic *)

(** A _tautology_ is a logical formula that is always
    provable. A formula is _propositional_ if it does not use
    quantifiers -- or at least, if quantifiers do not have to be
    instantiated to carry out the proof. The [intuition] tactic
    implements a decision procedure for propositional tautologies in
    Coq's constructive (that is, intuitionistic) logic. Even if a goal
    is not a propositional tautology, [intuition] will still attempt
    to reduce it to simpler subgoals. *)

Theorem intuition_succeed1 : forall (P : Prop),
    P -> P.
Proof. intuition. Qed.

Theorem intuition_succeed2 : forall (P Q : Prop),
    ~ (P \/ Q) -> ~P /\ ~Q.
Proof. intuition. Qed.

Theorem intuition_simplify1 : forall (P : Prop),
    ~~P -> P.
Proof.
  intuition. (* not a constructively valid formula *)
Abort.

Theorem intuition_simplify2 : forall (x y : nat) (P Q : nat -> Prop),
  x = y /\ (P x -> Q x) /\ P x -> Q y.
Proof.
  Fail congruence. (* the propositions stump it *)
  intuition. (* the [=] stumps it, but it simplifies the propositions *)
  congruence.
Qed.

(** In the previous example, neither [congruence] nor
    [intuition] alone can solve the goal. But after [intuition]
    simplifies the propositions involved in the goal, [congruence] can
    succeed. For situations like this, [intuition] takes an optional
    argument, which is a tactic to apply to all the unsolved goals
    that [intuition] generated. Using that we can offer a shorter
    proof: *)

Theorem intuition_simplify2' : forall (x y : nat) (P Q : nat -> Prop),
  x = y /\ (P x -> Q x) /\ P x -> Q y.
Proof.
  intuition congruence.
Qed.

(* ================================================================= *)
(** ** Exercises with Automatic Solvers *)

(** **** Exercise: 2 stars, standard (automatic_solvers)

    The exercises below are gleaned from previous chapters, where they
    were proved with (relatively) long proof scripts. Each should now
    be provable with just a single invocation of an automatic
    solver. *)

Theorem plus_id_exercise_from_basics : forall n m o : nat,
  n = m -> m = o -> n + m = m + o.
Proof.
  intuition.
Qed.

Theorem add_assoc_from_induction : forall n m p : nat,
    n + (m + p) = (n + m) + p.
Proof.
  lia.
Qed.

Theorem S_injective_from_tactics : forall (n m : nat),
  S n = S m ->
  n = m.
Proof.
  intuition.
Qed.

Theorem or_distributes_over_and_from_logic : forall P Q R : Prop,
    P \/ (Q /\ R) <-> (P \/ Q) /\ (P \/ R).
Proof.
  intuition.
Qed.

(** [] *)

(* ################################################################# *)
(** * Search Tactics *)

(** The automated solvers we just discussed are capable of finding
    proofs in specific domains. Some of them might pay attention to
    local hypotheses, but overall they don't make use of any custom
    lemmas we've proved, or that are provided by libraries that we
    load.

    Another kind of automation that Coq provides does just that: the
    [auto] tactic and its variants search for proofs that can be
    assembled out of hypotheses and lemmas. *)

(* ================================================================= *)
(** ** The [auto] Tactic *)

(** Until this chapter, our proof scripts mostly applied relevant
    hypotheses or lemmas by name, and one at a time. *)

Example auto_example_1 : forall (P Q R: Prop),
  (P -> Q) -> (Q -> R) -> P -> R.
Proof.
  intros P Q R H1 H2 H3.
  apply H2. apply H1. apply H3.
Qed.

(** The [auto] tactic frees us from this drudgery by _searching_ for a
    sequence of applications that will prove the goal: *)

Example auto_example_1' : forall (P Q R: Prop),
  (P -> Q) -> (Q -> R) -> P -> R.
Proof.
  auto.
Qed.

(** The [auto] tactic solves goals that are solvable by any combination of
     - [intros] and
     - [apply] (of hypotheses from the local context, by default). *)

(** Using [auto] is always "safe" in the sense that it will
    never fail and will never change the proof state: either it
    completely solves the current goal, or it does nothing. *)

(** Here is a more interesting example showing [auto]'s power: *)

Example auto_example_2 : forall P Q R S T U : Prop,
  (P -> Q) ->
  (P -> R) ->
  (T -> R) ->
  (S -> T -> U) ->
  ((P -> Q) -> (P -> S)) ->
  T ->
  P ->
  U.
Proof. auto. Qed.

(** Proof search could, in principle, take an arbitrarily long time,
    so there are limits to how far [auto] will search by default. *)

Example auto_example_3 : forall (P Q R S T U: Prop),
  (P -> Q) ->
  (Q -> R) ->
  (R -> S) ->
  (S -> T) ->
  (T -> U) ->
  P ->
  U.
Proof.
  (* When it cannot solve the goal, [auto] does nothing *)
  auto.
  (* Optional argument says how deep to search (default is 5) *)
  auto 6.
Qed.

(** The [auto] tactic considers the hypotheses in the current context
    together with a _hint database_ of other lemmas and constructors.
    Some common facts about equality and logical operators are
    installed in the hint database by default. *)

Example auto_example_4 : forall P Q R : Prop,
  Q ->
  (Q -> R) ->
  P \/ (Q /\ R).
Proof. auto. Qed.

(** If we want to see which facts [auto] is using, we can use
    [info_auto] instead. *)

Example auto_example_5 : 2 = 2.
Proof.
  (* [auto] subsumes [reflexivity] because [eq_refl] is in the hint
     database. *)
  info_auto.
Qed.

(** We can extend the hint database with theorem [t] just for the
    purposes of one application of [auto] by writing [auto using
    t]. *)

Lemma le_antisym : forall n m: nat, (n <= m /\ m <= n) -> n = m.
Proof. intros. lia. Qed.

Example auto_example_6 : forall n m p : nat,
  (n <= p -> (n <= m /\ m <= n)) ->
  n <= p ->
  n = m.
Proof.
  auto using le_antisym.
Qed.

(** Of course, in any given development there will probably be
    some specific constructors and lemmas that are used very often in
    proofs.  We can add these to a hint database named [db] by writing

      Create HintDb db.

    to create the database, then

      Hint Resolve T : db.

    to add [T] to the database, where [T] is a top-level theorem or a
    constructor of an inductively defined proposition (i.e., anything
    whose type is an implication). We tell [auto] to use that database
    by writing [auto with db]. Technically creation of the database
    is optional; Coq will create it automatically the first time
    we use [Hint]. *)

Create HintDb le_db.
Hint Resolve le_antisym : le_db.

Example auto_example_6' : forall n m p : nat,
  (n <= p -> (n <= m /\ m <= n)) ->
  n <= p ->
  n = m.
Proof.
  auto with le_db.
Qed.

(** As a shorthand, we can write

      Hint Constructors c : db.

    to tell Coq to do a [Hint Resolve] for _all_ of the constructors
    from the inductive definition of [c].

    It is also sometimes necessary to add

      Hint Unfold d : db.

    where [d] is a defined symbol, so that [auto] knows to expand uses
    of [d], thus enabling further possibilities for applying lemmas that
    it knows about. *)

Definition is_fortytwo x := (x = 42).

Example auto_example_7: forall x,
  (x <= 42 /\ 42 <= x) -> is_fortytwo x.
Proof.
  auto.  (* does nothing *)
Abort.

Hint Unfold is_fortytwo : le_db.

Example auto_example_7' : forall x,
  (x <= 42 /\ 42 <= x) -> is_fortytwo x.
Proof. info_auto with le_db. Qed.

(** The "global" database that [auto] always uses is named [core].
    You can add your own hints to it, but the Coq manual discourages
    that, preferring instead to have specialized databases for
    specific developments. Many of the important libraries have their
    own hint databases that you can tag in: [arith], [bool], [datatypes]
    (including lists), etc. *)

Example auto_example_8 : forall (n m : nat),
    n + m = m + n.
Proof.
  auto. (* no progress *)
  info_auto with arith. (* uses [Nat.add_comm] *)
Qed.

(** **** Exercise: 3 stars, standard (re_opt_match_auto) *)

(** Use [auto] to shorten your proof of [re_opt_match] even
    more. Eliminate all uses of [apply], thus removing the need to
    name specific constructors and lemmas about regular expressions.
    The number of lines of proof script won't decrease that much,
    because [auto] won't be able to find [induction], [destruct], or
    [inversion] opportunities by itself.

    Hint: again, use a bottom-up approach. Always keep the proof
    compiling. You might find it easier to return to the original,
    very long proof, and shorten it, rather than starting with
    [re_opt_match']; but, either way can work. *)

Lemma re_opt_match'' : forall T (re: reg_exp T) s,
  s =~ re -> s =~ re_opt re.
Proof.
  intros T re s M.
  induction M
    as [| x'
        | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
        | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
        | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2].
  - (* MEmpty *) simpl; apply MEmpty.
  - (* MChar *) simpl; apply MChar.
  - (* MApp *)
    simpl;
      destruct re1;
      [inversion IH1 | inversion IH1; simpl; destruct re2; apply IH2 | | | |];
      (destruct re2;
       [inversion IH2 | inversion IH2; rewrite app_nil_r; apply IH1 | | | | ];
       (apply MApp; [apply IH1 | apply IH2])).
  - (* MUnionL *)
    simpl;
      destruct re1;
      [inversion IH | | | | |];
      destruct re2; try apply MUnionL; apply IH.
  - (* MUnionR *)
    simpl;
      destruct re1;
      [apply IH | | | | |];
      (destruct re2; [inversion IH | | | | |]; apply MUnionR; apply IH).
 - (* MStar0 *)
   simpl;
     destruct re; try apply MEmpty; try apply MStar0.
 - (* MStarApp *)
   simpl;
    destruct re;
    [inversion IH1 | inversion IH1; inversion IH2; apply MEmpty | | | |];
    (apply star_app; [apply MStar1; apply IH1 | apply IH2]).
Qed.  
(* Do not modify the following line: *)
Definition manual_grade_for_re_opt_match'' : option (nat*string) := None.
(** [] *)

(** **** Exercise: 3 stars, advanced, optional (pumping_redux)

    Use [auto], [lia], and any other useful tactics from this chapter
    to shorten your proof (or the "official" solution proof) of the
    weak Pumping Lemma exercise from [IndProp]. *)

Import Pumping.

Lemma weak_pumping : forall T (re : reg_exp T) s,
    s =~ re ->
    pumping_constant re <= length s ->
    exists s1 s2 s3,
      s = s1 ++ s2 ++ s3 /\
        s2 <> [] /\ forall m, s1 ++ napp m s2 ++ s3 =~ re(** * IndProp: Inductively Defined Propositions *)

Set Warnings "-notation-overridden,-parsing,-deprecated-hint-without-locality".
From LF Require Export Logic.

(* ################################################################# *)
(** * Inductively Defined Propositions *)

(** In the [Logic] chapter, we looked at several ways of writing
    propositions, including conjunction, disjunction, and existential
    quantification.

    In this chapter, we bring yet another new tool into the mix:
    _inductively defined propositions_.

    To begin, some examples... *)

(* ================================================================= *)
(** ** Example: The Collatz Conjecture *)

(** The _Collatz Conjecture_ is a famous open problem in number
    theory.

    Its statement is quite simple.  First, we define a function [f]
    on numbers, as follows: *)

Fixpoint div2 (n : nat) :=
  match n with
    0 => 0
  | 1 => 0
  | S (S n) => S (div2 n)
  end.

Definition f (n : nat) :=
  if even n then div2 n
  else (3 * n) + 1.

(** Next, we look at what happens when we repeatedly apply [f] to
    some given starting number.  For example, [f 12] is [6], and [f
    6] is [3], so by repeatedly applying [f] we get the sequence
    [12, 6, 3, 10, 5, 16, 8, 4, 2, 1].

    Similarly, if we start with [19], we get the longer sequence
    [19, 58, 29, 88, 44, 22, 11, 34, 17, 52, 26, 13, 40, 20, 10, 5,
    16, 8, 4, 2, 1].

    Both of these sequences eventually reach [1].  The question
    posed by Collatz was: Is the sequence starting from _any_
    natural number guaranteed to reach [1] eventually? *)

(** To formalize this question in Coq, we might try to define a
    recursive _function_ that calculates the total number of steps
    that it takes for such a sequence to reach [1]. *)

Fail Fixpoint reaches_1_in (n : nat) :=
  if n =? 1 then true
  else 1 + reaches_1_in (f n).

(** This definition is rejected by Coq's termination checker, since
    the argument to the recursive call, [f n], is not "obviously
    smaller" than [n].

    Indeed, this isn't just a pointless limitation: functions in Coq
    are required to be total, to ensure logical consistency.

    Moreover, we can't fix it by devising a more clever termination
    checker: deciding whether this particular function is total
    would be equivalent to settling the Collatz conjecture! *)

(** Fortunately, there is another way to do it: We can express the
    concept "reaches [1] eventually" as an _inductively defined
    property_ of numbers: *)

Inductive Collatz_holds_for : nat -> Prop :=
  | Chf_done : Collatz_holds_for 1
  | Chf_more (n : nat) : Collatz_holds_for (f n) -> Collatz_holds_for n.

(** What we've done here is to use Coq's [Inductive] definition
    mechanism to characterize the property "Collatz holds for..." by
    stating two different ways in which it can hold: (1) Collatz holds
    for [1] and (2) if Collatz holds for [f n] then it holds for
    [n]. *)

(** For particular numbers, we can now argue that the Collatz sequence
    reaches [1] like this (again, we'll go through the details of how
    it works a bit later in the chapter): *)

Example Collatz_holds_for_12 : Collatz_holds_for 12.
Proof.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_more. unfold f. simpl.
  apply Chf_done.  Qed.

(** The Collatz conjecture then states that the sequence beginning
    from _any_ number reaches [1]: *)

Conjecture collatz : forall n, Collatz_holds_for n.

(** If you succeed in proving this conjecture, you've got a bright
    future as a number theorist!  But don't spend too long on it --
    it's been open since 1937. *)

(* ================================================================= *)
(** ** Example: Ordering *)

(** A binary _relation_ on a set [X] is a family of propositions
    parameterized by two elements of [X] -- i.e., a proposition
    about pairs of elements of [X].  *)

(** For example, one familiar binary relation on [nat] is [le], the
    less-than-or-equal-to relation.  We've already seen how to define
    it as a boolean computation.  Here is a "direct" propositional
    definition. *)

Module LePlayground.

(** The following definition says that there are two ways to
    show that one number is less than or equal to another: either
    observe that they are the same number, or, if the second has the
    form [S m], give evidence that the first is less than or equal to
    [m]. *)

Inductive le : nat -> nat -> Prop :=
  | le_n (n : nat)   : le n n
  | le_S (n m : nat) : le n m -> le n (S m).

Notation "n <= m" := (le n m) (at level 70).

Example le_3_5 : 3 <= 5.
Proof.
  apply le_S. apply le_S. apply le_n. Qed.

End LePlayground.

Module LePlayground1.

(** (By "reserving" the notation before defining the [Inductive], we
    can use it in the definition.) *)

Reserved Notation "n <= m" (at level 70).

Inductive le : nat -> nat -> Prop :=
  | le_n (n : nat)   : n <= n
  | le_S (n m : nat) : n <= m -> n <= (S m)

  where "n <= m" := (le n m).

End LePlayground1.

(* ================================================================= *)
(** ** Example: Transitive Closure *)

(** As another example, the _transitive closure_ of a relation [R]
    is the smallest relation that contains [R] and that is
    transitive.  *)

Inductive clos_trans {X: Type} (R: X->X->Prop) : X->X->Prop :=
  | t_step (x y : X) :
      R x y ->
      clos_trans R x y
  | t_trans (x y z : X) :
      clos_trans R x y ->
      clos_trans R y z ->
      clos_trans R x z.

(** For example, suppose we define a "parent of" relation on a group
    of people... *)

Inductive Person : Type := Sage | Cleo | Ridley | Moss.

Inductive parent_of : Person -> Person -> Prop :=
  po_SC : parent_of Sage Cleo
| po_SR : parent_of Sage Ridley
| po_CM : parent_of Cleo Moss.

(** Then we can define "ancestor of" as its transitive closure: *)

Definition ancestor_of : Person -> Person -> Prop :=
  clos_trans parent_of.

Example ancestor_of1 : ancestor_of Sage Moss.
Proof.
  unfold ancestor_of. apply t_trans with Cleo.
  - apply t_step. apply po_SC.
  - apply t_step. apply po_CM. Qed.

(** **** Exercise: 1 star, standard, optional (close_refl_trans)

    How would you modify this definition so that it defines _reflexive
    and_ transitive closure?  How about reflexive, symmetric, and
    transitive closure? *)

(* FILL IN HERE

    [] *)

(* ================================================================= *)
(** ** Example: Permutations *)

(** The familiar mathematical concept of _permutation_ also has an
    elegant formulation as an inductive relation.  For simplicity,
    let's focus on permutations of lists with exactly three
    elements. *)

Inductive Perm3 {X : Type} : list X -> list X -> Prop :=
  | perm3_swap12 (a b c : X) :
      Perm3 [a;b;c] [b;a;c]
  | perm3_swap23 (a b c : X) :
      Perm3 [a;b;c] [a;c;b]
  | perm3_trans (l1 l2 l3 : list X) :
      Perm3 l1 l2 -> Perm3 l2 l3 -> Perm3 l1 l3.

(** This definition says:
      - If [l2] can be obtained from [l1] by swapping the first and
        second elements, then [l2] is a permutation of [l1].
      - If [l2] can be obtained from [l1] by swapping the second and
        third elements, then [l2] is a permutation of [l1].
      - If [l2] is a permutation of [l1] and [l3] is a permutation of
        [l2], then [l3] is a permutation of [l1]. *)

(** **** Exercise: 1 star, standard, optional (perm)

    According to this definition, is [[1;2;3]] a permutation of
    [[3;2;1]]?  Is [[1;2;3]] a permutation of itself? *)

(* FILL IN HERE

    [] *)

Example Perm3_example1 : Perm3 [1;2;3] [2;3;1].
Proof.
  apply perm3_trans with [2;1;3].
  - apply perm3_swap12.
  - apply perm3_swap23.   Qed.

(* ================================================================= *)
(** ** Example: Evenness (yet again) *)

(** We've already seen two ways of stating a proposition that a number
    [n] is even: We can say

      (1) [even n = true], or

      (2) [exists k, n = double k].

    A third possibility, which we'll use as a running example for the
    rest of this chapter, is to say that [n] is even if we can
    _establish_ its evenness from the following rules:

       - The number [0] is even.
       - If [n] is even, then [S (S n)] is even. *)

(** (Defining evenness in this way may seem a bit confusing,
    since we have already seen another perfectly good way of doing
    it -- "[n] is even if it is equal to the result of doubling some
    number". It makes a convenient running example because it is
    simple and compact, but we will see more compelling examples in
    future chapters.) *)

(** To illustrate how this new definition of evenness works,
    let's imagine using it to show that [4] is even. First, we give
    the rules names for easy reference:
       - Rule [ev_0]: The number [0] is even.
       - Rule [ev_SS]: If [n] is even, then [S (S n)] is even.

    Now, by rule [ev_SS], it suffices to show that [2] is even. This,
    in turn, is again guaranteed by rule [ev_SS], as long as we can
    show that [0] is even. But this last fact follows directly from
    the [ev_0] rule. *)

(** We can translate the informal definition of evenness from above
    into a formal [Inductive] declaration, where each "way that a
    number can be even" corresponds to a separate constructor: *)

Inductive ev : nat -> Prop :=
  | ev_0                       : ev 0
  | ev_SS (n : nat) (H : ev n) : ev (S (S n)).

(** This definition is interestingly different from previous uses of
    [Inductive].  For one thing, we are defining not a [Type] (like
    [nat]) or a function yielding a [Type] (like [list]), but rather a
    function from [nat] to [Prop] -- that is, a property of numbers.
    But what is really new is that, because the [nat] argument of [ev]
    appears to the _right_ of the colon on the first line, it is
    allowed to take _different_ values in the types of different
    constructors: [0] in the type of [ev_0] and [S (S n)] in the type
    of [ev_SS].  Accordingly, the type of each constructor must be
    specified explicitly (after a colon), and each constructor's type
    must have the form [ev n] for some natural number [n].

    In contrast, recall the definition of [list]:

    Inductive list (X:Type) : Type :=
      | nil
      | cons (x : X) (l : list X).

    or equivalently:

    Inductive list (X:Type) : Type :=
      | nil                       : list X
      | cons (x : X) (l : list X) : list X.

   This definition introduces the [X] parameter _globally_, to the
   _left_ of the colon, forcing the result of [nil] and [cons] to be
   the same type (i.e., [list X]).  But if we had tried to bring [nat]
   to the left of the colon in defining [ev], we would have seen an
   error: *)

Fail Inductive wrong_ev (n : nat) : Prop :=
  | wrong_ev_0 : wrong_ev 0
  | wrong_ev_SS (H: wrong_ev n) : wrong_ev (S (S n)).
(* ===> Error: Last occurrence of "[wrong_ev]" must have "[n]" as 1st
        argument in "[wrong_ev 0]". *)

(** In an [Inductive] definition, an argument to the type constructor
    on the left of the colon is called a "parameter", whereas an
    argument on the right is called an "index" or "annotation."

    For example, in [Inductive list (X : Type) := ...], the [X] is a
    parameter, while in [Inductive ev : nat -> Prop := ...], the
    unnamed [nat] argument is an index. *)

(** We can think of this as defining a Coq property [ev : nat ->
    Prop], together with "evidence constructors" [ev_0 : ev 0] and
    [ev_SS : forall n, ev n -> ev (S (S n))]. *)

(** These evidence constructors can be thought of as "primitive
    evidence of evenness", and they can be used just like proven
    theorems.  In particular, we can use Coq's [apply] tactic with the
    constructor names to obtain evidence for [ev] of particular
    numbers... *)

Theorem ev_4 : ev 4.
Proof. apply ev_SS. apply ev_SS. apply ev_0. Qed.

(** ... or we can use function application syntax to combine several
    constructors: *)

Theorem ev_4' : ev 4.
Proof. apply (ev_SS 2 (ev_SS 0 ev_0)). Qed.

(** In this way, we can also prove theorems that have hypotheses
    involving [ev]. *)

Theorem ev_plus4 : forall n, ev n -> ev (4 + n).
Proof.
  intros n. simpl. intros Hn.  apply ev_SS. apply ev_SS. apply Hn.
Qed.

(** **** Exercise: 1 star, standard (ev_double) *)
Theorem ev_double : forall n,
  ev (double n).
Proof.
  intros n.
  induction n.
  - apply ev_0.
  - simpl. apply ev_SS. apply IHn.
Qed.
(** [] *)

(* ################################################################# *)
(** * Using Evidence in Proofs *)

(** Besides _constructing_ evidence that numbers are even, we can also
    _destruct_ such evidence, reasoning about how it could have been
    built.

    Defining [ev] with an [Inductive] declaration tells Coq not
    only that the constructors [ev_0] and [ev_SS] are valid ways to
    build evidence that some number is [ev], but also that these two
    constructors are the _only_ ways to build evidence that numbers
    are [ev]. *)

(** In other words, if someone gives us evidence [E] for the assertion
    [ev n], then we know that [E] must be one of two things:

      - [E] is [ev_0] (and [n] is [O]), or
      - [E] is [ev_SS n' E'] (and [n] is [S (S n')], where [E'] is
        evidence for [ev n']). *)

(** This suggests that it should be possible to analyze a
    hypothesis of the form [ev n] much as we do inductively defined
    data structures; in particular, it should be possible to argue by
    _case analysis_ or by _induction_ on such evidence.  Let's look at a
    few examples to see what this means in practice. *)

(* ================================================================= *)
(** ** Inversion on Evidence *)

(** Suppose we are proving some fact involving a number [n], and
    we are given [ev n] as a hypothesis.  We already know how to
    perform case analysis on [n] using [destruct] or [induction],
    generating separate subgoals for the case where [n = O] and the
    case where [n = S n'] for some [n'].  But for some proofs we may
    instead want to analyze the evidence for [ev n] _directly_.

    As a tool for such proofs, we can formalize the intuitive
    characterization that we gave above for evidence of [ev n], using
    [destruct]. *)

Theorem ev_inversion : forall (n : nat),
    ev n ->
    (n = 0) \/ (exists n', n = S (S n') /\ ev n').
Proof.
  intros n E.  destruct E as [ | n' E'] eqn:EE.
  - (* E = ev_0 : ev 0 *)
    left. reflexivity.
  - (* E = ev_SS n' E' : ev (S (S n')) *)
    right. exists n'. split. reflexivity. apply E'.
Qed.

(** Facts like this are often called "inversion lemmas" because they
    allow us to "invert" some given information to reason about all
    the different ways it could have been derived.

    Here, there are two ways to prove [ev n], and the inversion lemma
    makes this explicit. *)

(** We can use the inversion lemma that we proved above to help
    structure proofs: *)

Theorem evSS_ev : forall n, ev (S (S n)) -> ev n.
Proof.
  intros n H. apply ev_inversion in H.  destruct H as [H0|H1].
  - discriminate H0.
  - destruct H1 as [n' [Hnm Hev]]. injection Hnm as Heq.
    rewrite Heq. apply Hev.
Qed.

(** Note how the inversion lemma produces two subgoals, which
    correspond to the two ways of proving [ev].  The first subgoal is
    a contradiction that is discharged with [discriminate].  The
    second subgoal makes use of [injection] and [rewrite].

    Coq provides a handy tactic called [inversion] that factors out
    this common pattern, saving us the trouble of explicitly stating
    and proving an inversion lemma for every [Inductive] definition we
    make.

    Here, the [inversion] tactic can detect (1) that the first case,
    where [n = 0], does not apply and (2) that the [n'] that appears
    in the [ev_SS] case must be the same as [n].  It includes an
    "[as]" annotation similar to [destruct], allowing us to assign
    names rather than have Coq choose them. *)

Theorem evSS_ev' : forall n,
  ev (S (S n)) -> ev n.
Proof.
  intros n E.  inversion E as [| n' E' Heq].
  (* We are in the [E = ev_SS n' E'] case now. *)
  apply E'.
Qed.

(** The [inversion] tactic can apply the principle of explosion to
    "obviously contradictory" hypotheses involving inductively defined
    properties, something that takes a bit more work using our
    inversion lemma. Compare: *)

Theorem one_not_even : ~ ev 1.
Proof.
  intros H. apply ev_inversion in H.  destruct H as [ | [m [Hm _]]].
  - discriminate H.
  - discriminate Hm.
Qed.

Theorem one_not_even' : ~ ev 1.
Proof.
  intros H. inversion H. Qed.

(** **** Exercise: 1 star, standard (inversion_practice)

    Prove the following result using [inversion].  (For extra
    practice, you can also prove it using the inversion lemma.) *)

Theorem SSSSev__even : forall n,
  ev (S (S (S (S n)))) -> ev n.
Proof.
  intros n E.
  inversion E as [ | n' E' Heq ].
  inversion E' as [ | n'' E'' Heq'].
  assumption.
Qed.
  (** [] *)

(** **** Exercise: 1 star, standard (ev5_nonsense)

    Prove the following result using [inversion]. *)

Theorem ev5_nonsense :
  ev 5 -> 2 + 2 = 9.
Proof.
  intros H.
  inversion H. inversion H1. inversion H3.
Qed.
(** [] *)

(** The [inversion] tactic does quite a bit of work. For
    example, when applied to an equality assumption, it does the work
    of both [discriminate] and [injection]. In addition, it carries
    out the [intros] and [rewrite]s that are typically necessary in
    the case of [injection]. It can also be applied to analyze
    evidence for arbitrary inductively defined propositions, not just
    equality.  As examples, we'll use it to re-prove some theorems
    from chapter [Tactics].  (Here we are being a bit lazy by
    omitting the [as] clause from [inversion], thereby asking Coq to
    choose names for the variables and hypotheses that it introduces.) *)

Theorem inversion_ex1 : forall (n m o : nat),
  [n; m] = [o; o] -> [n] = [m].
Proof.
  intros n m o H. inversion H. reflexivity. Qed.

Theorem inversion_ex2 : forall (n : nat),
  S n = O -> 2 + 2 = 5.
Proof.
  intros n contra. inversion contra. Qed.

(** Here's how [inversion] works in general.
      - Suppose the name [H] refers to an assumption [P] in the
        current context, where [P] has been defined by an [Inductive]
        declaration.
      - Then, for each of the constructors of [P], [inversion H]
        generates a subgoal in which [H] has been replaced by the
        specific conditions under which this constructor could have
        been used to prove [P].
      - Some of these subgoals will be self-contradictory; [inversion]
        throws these away.
      - The ones that are left represent the cases that must be proved
        to establish the original goal.  For those, [inversion] adds
        to the proof context all equations that must hold of the
        arguments given to [P] -- e.g., [n' = n] in the proof of
        [evSS_ev]). *)

(** The [ev_double] exercise above shows that our new notion of
    evenness is implied by the two earlier ones (since, by
    [even_bool_prop] in chapter [Logic], we already know that
    those are equivalent to each other). To show that all three
    coincide, we just need the following lemma. *)

Lemma ev_Even_firsttry : forall n,
  ev n -> Even n.
Proof.
  (* WORKED IN CLASS *) unfold Even.

(** We could try to proceed by case analysis or induction on [n].  But
    since [ev] is mentioned in a premise, this strategy seems
    unpromising, because (as we've noted before) the induction
    hypothesis will talk about [n-1] (which is _not_ even!).  Thus, it
    seems better to first try [inversion] on the evidence for [ev].
    Indeed, the first case can be solved trivially. And we can
    seemingly make progress on the second case with a helper lemma. *)

  intros n E. inversion E as [EQ' | n' E' EQ'].
  - (* E = ev_0 *) exists 0. reflexivity.
  - (* E = ev_SS n' E'

    Unfortunately, the second case is harder.  We need to show [exists
    n0, S (S n') = double n0], but the only available assumption is
    [E'], which states that [ev n'] holds.  Since this isn't directly
    useful, it seems that we are stuck and that performing case
    analysis on [E] was a waste of time.

    If we look more closely at our second goal, however, we can see
    that something interesting happened: By performing case analysis
    on [E], we were able to reduce the original result to a similar
    one that involves a _different_ piece of evidence for [ev]: namely
    [E'].  More formally, we could finish our proof if we could show
    that

        exists k', n' = double k',

    which is the same as the original statement, but with [n'] instead
    of [n].  Indeed, it is not difficult to convince Coq that this
    intermediate result would suffice. *)
    assert (H: (exists k', n' = double k')
               -> (exists n0, S (S n') = double n0)).
        { intros [k' EQ'']. exists (S k'). simpl.
          rewrite <- EQ''. reflexivity. }
    apply H.

    (** Unfortunately, now we are stuck. To see this clearly, let's
        move [E'] back into the goal from the hypotheses. *)

    generalize dependent E'.

    (** Now it is obvious that we are trying to prove another instance
        of the same theorem we set out to prove -- only here we are
        talking about [n'] instead of [n]. *)
Abort.

(* ================================================================= *)
(** ** Induction on Evidence *)

(** If this story feels familiar, it is no coincidence: We
    encountered similar problems in the [Induction] chapter, when
    trying to use case analysis to prove results that required
    induction.  And once again the solution is... induction! *)

(** The behavior of [induction] on evidence is the same as its
    behavior on data: It causes Coq to generate one subgoal for each
    constructor that could have used to build that evidence, while
    providing an induction hypothesis for each recursive occurrence of
    the property in question.

    To prove that a property of [n] holds for all even numbers (i.e.,
    those for which [ev n] holds), we can use induction on [ev
    n]. This requires us to prove two things, corresponding to the two
    ways in which [ev n] could have been constructed. If it was
    constructed by [ev_0], then [n=0] and the property must hold of
    [0]. If it was constructed by [ev_SS], then the evidence of [ev n]
    is of the form [ev_SS n' E'], where [n = S (S n')] and [E'] is
    evidence for [ev n']. In this case, the inductive hypothesis says
    that the property we are trying to prove holds for [n']. *)

(** Let's try proving that lemma again: *)

Inductive isZero : nat -> Prop :=
| zero: isZero 0.

Check isZero_ind.

Lemma ev_Even : forall n,
  ev n -> Even n.
Proof.
  intros n E.
  induction E as [|n' E' IH].
  - (* E = ev_0 *)
    unfold Even. exists 0. reflexivity.
  - (* E = ev_SS n' E'
       with IH : Even n' *)
    unfold Even in IH.
    destruct IH as [k Hk].
    rewrite Hk.
    unfold Even. exists (S k). simpl. reflexivity.
Qed.

(** Here, we can see that Coq produced an [IH] that corresponds
    to [E'], the single recursive occurrence of [ev] in its own
    definition.  Since [E'] mentions [n'], the induction hypothesis
    talks about [n'], as opposed to [n] or some other number. *)

(** The equivalence between the second and third definitions of
    evenness now follows. *)

Theorem ev_Even_iff : forall n,
  ev n <-> Even n.
Proof.
  intros n. split.
  - (* -> *) apply ev_Even.
  - (* <- *) unfold Even. intros [k Hk]. rewrite Hk. apply ev_double.
Qed.

(** As we will see in later chapters, induction on evidence is a
    recurring technique across many areas -- in particular for
    formalizing the semantics of programming languages. *)

(** The following exercises provide simple examples of this
    technique, to help you familiarize yourself with it. *)

(** **** Exercise: 2 stars, standard (ev_sum) *)
Lemma add_zero : forall m : nat, m + 0 = m.
Proof.
   induction m.
      - reflexivity.
      - simpl. rewrite -> IHm. reflexivity.
Qed.

Theorem ev_sum : forall n m, ev n -> ev m -> ev (n + m).
Proof.
  intros n m Hn Hm.
  induction Hn as [ HA | n' HB ].
  - simpl. assumption.
  - simpl. apply ev_SS. assumption.
Qed.
(** [] *)

(** **** Exercise: 4 stars, advanced, optional (ev'_ev)

    In general, there may be multiple ways of defining a
    property inductively.  For example, here's a (slightly contrived)
    alternative definition for [ev]: *)

Inductive ev' : nat -> Prop :=
  | ev'_0 : ev' 0
  | ev'_2 : ev' 2
  | ev'_sum n m (Hn : ev' n) (Hm : ev' m) : ev' (n + m).

(** Prove that this definition is logically equivalent to the old one.
    To streamline the proof, use the technique (from the [Logic]
    chapter) of applying theorems to arguments, and note that the same
    technique works with constructors of inductively defined
    propositions. *)

Lemma ev'_ev_forward: forall n : nat, ev' n -> ev n.
Proof.
  intros n.
  intros H'. induction H' as [H0 | H2 | n' m' Hn' Hm' ].
    + apply ev_0.
    + apply ev_SS. apply ev_0.
    + apply ev_sum. assumption. assumption.
Qed.

Theorem ev'_ev : forall n, ev' n <-> ev n.
Proof.
  intros n.
  split.
  -  apply ev'_ev_forward.
  -  intros H'. induction H' as [ |n' HE ].
     + apply ev'_0.
Abort.
(** [] *)

(** **** Exercise: 3 stars, advanced, especially useful (ev_ev__ev) *)
Theorem ev_ev__ev : forall n m,
  ev (n+m) -> ev n -> ev m.
  (* Hint: There are two pieces of evidence you could attempt to induct upon
      here. If one doesn't work, try the other. *)
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 3 stars, standard, optional (ev_plus_plus)

    This exercise can be completed without induction or case analysis.
    But, you will need a clever assertion and some tedious rewriting.
    Hint: Is [(n+m) + (n+p)] even? *)

Theorem ev_plus_plus : forall n m p,
  ev (n+m) -> ev (n+p) -> ev (m+p).
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(* ################################################################# *)
(** * Inductive Relations *)

(** A proposition parameterized by a number (such as [ev])
    can be thought of as a _property_ -- i.e., it defines
    a subset of [nat], namely those numbers for which the proposition
    is provable.  In the same way, a two-argument proposition can be
    thought of as a _relation_ -- i.e., it defines a set of pairs for
    which the proposition is provable. *)

Module Playground.

(** Just like properties, relations can be defined inductively.  One
    useful example is the "less than or equal to" relation on numbers
    that we briefly saw above. *)

Inductive le : nat -> nat -> Prop :=
  | le_n (n : nat)                : le n n
  | le_S (n m : nat) (H : le n m) : le n (S m).

Notation "n <= m" := (le n m).

(** (We've written the definition a bit differently this time,
    giving explicit names to the arguments to the constructors and
    moving them to the left of the colons.) *)

(** Proofs of facts about [<=] using the constructors [le_n] and
    [le_S] follow the same patterns as proofs about properties, like
    [ev] above. We can [apply] the constructors to prove [<=]
    goals (e.g., to show that [3<=3] or [3<=6]), and we can use
    tactics like [inversion] to extract information from [<=]
    hypotheses in the context (e.g., to prove that [(2 <= 1) ->
    2+2=5].) *)

(** Here are some sanity checks on the definition.  (Notice that,
    although these are the same kind of simple "unit tests" as we gave
    for the testing functions we wrote in the first few lectures, we
    must construct their proofs explicitly -- [simpl] and
    [reflexivity] don't do the job, because the proofs aren't just a
    matter of simplifying computations.) *)

Theorem test_le1 :
  3 <= 3.
Proof.
  (* WORKED IN CLASS *)
  apply le_n.  Qed.

Theorem test_le2 :
  3 <= 6.
Proof.
  (* WORKED IN CLASS *)
  apply le_S. apply le_S. apply le_S. apply le_n.  Qed.

Theorem test_le3 :
  (2 <= 1) -> 2 + 2 = 5.
Proof.
  (* WORKED IN CLASS *)
  intros H. inversion H. inversion H2.  Qed.

(** The "strictly less than" relation [n < m] can now be defined
    in terms of [le]. *)

Definition lt (n m : nat) := le (S n) m.

Notation "n < m" := (lt n m).

End Playground.

(** **** Exercise: 2 stars, standard, optional (total_relation)

    Define an inductive binary relation [total_relation] that holds
    between every pair of natural numbers. *)

Inductive total_relation : nat -> nat -> Prop :=
| eq (n : nat) (m : nat) : total_relation n m
| ge (n : nat) (m : nat) : total_relation n m -> total_relation (S n) m.

Theorem total_relation_is_total : forall n m, total_relation n m.
Proof.
  intros n m.
  induction n.
  - apply (eq 0 m).
  - apply ge. apply IHn.
Qed.
(** [] *)

(** **** Exercise: 2 stars, standard, optional (empty_relation)

    Define an inductive binary relation [empty_relation] (on numbers)
    that never holds. *)

Inductive empty_relation : nat -> nat -> Prop :=
.

Theorem empty_relation_is_empty : forall n m, ~ empty_relation n m.
Proof.
  intros n m.
  unfold not.
  intros H.
  inversion H.
Qed.
(** [] *)

(** From the definition of [le], we can sketch the behaviors of
    [destruct], [inversion], and [induction] on a hypothesis [H]
    providing evidence of the form [le e1 e2].  Doing [destruct H]
    will generate two cases. In the first case, [e1 = e2], and it
    will replace instances of [e2] with [e1] in the goal and context.
    In the second case, [e2 = S n'] for some [n'] for which [le e1 n']
    holds, and it will replace instances of [e2] with [S n'].
    Doing [inversion H] will remove impossible cases and add generated
    equalities to the context for further use. Doing [induction H]
    will, in the second case, add the induction hypothesis that the
    goal holds when [e2] is replaced with [n']. *)

(** Here are a number of facts about the [<=] and [<] relations that
    we are going to need later in the course.  The proofs make good
    practice exercises. *)

(** **** Exercise: 5 stars, standard, optional (le_and_lt_facts) *)
Search le.

Lemma le_trans : forall m n o, m <= n -> n <= o -> m <= o.
Proof.
  intros m n o.
  intros Hmn Hno.
  induction Hno.
  -  assumption.
  -  apply (le_S m m0). assumption.
Qed.

Theorem O_le_n : forall n,
  0 <= n.
Proof.
  induction n.
  - apply le_n.
  - apply le_S. apply IHn.
Qed.
Theorem n_le_m__Sn_le_Sm : forall n m,
  n <= m -> S n <= S m.
Proof.
  intros n m.
  intros Hle.
  induction Hle.
  - apply le_n.
  - apply le_S. apply IHHle.
Qed.

Theorem Sn_le_Sm__n_le_m : forall n m,
  S n <= S m -> n <= m.
Proof.
  intros n m Hnm.
  induction m.
  - inversion Hnm as [H' | n' M' H].
    + apply le_n.
    + inversion M'.
  - inversion Hnm.
    + apply le_n.
    + apply IHm in H0. apply le_S in H0. apply H0.
Qed.

Search orb.

Theorem lt_ge_cases : forall n m, n < m \/ n >= m.
Proof.
  intros n m.
  generalize dependent m.
  induction n.
  - induction m as [ | m' [HA | HB] ].
    + right. apply le_n.
    + left.
Abort.

Theorem le_plus_l : forall a b,
  a <= a + b.
Proof.
  (* FILL IN HERE *) Admitted.

Theorem plus_le : forall n1 n2 m,
  n1 + n2 <= m ->
  n1 <= m /\ n2 <= m.
Proof.
 (* FILL IN HERE *) Admitted.

Theorem add_le_cases : forall n m p q,
  n + m <= p + q -> n <= p \/ m <= q.
  (** Hint: May be easiest to prove by induction on [n]. *)
Proof.
(* FILL IN HERE *) Admitted.

Theorem plus_le_compat_l : forall n m p,
  n <= m ->
  p + n <= p + m.
Proof.
  (* FILL IN HERE *) Admitted.

Theorem plus_le_compat_r : forall n m p,
  n <= m ->
  n + p <= m + p.
Proof.
  (* FILL IN HERE *) Admitted.

Theorem le_plus_trans : forall n m p,
  n <= m ->
  n <= m + p.
Proof.
  (* FILL IN HERE *) Admitted.

Theorem n_lt_m__n_le_m : forall n m,
  n < m ->
  n <= m.
Proof.
  (* FILL IN HERE *) Admitted.

Theorem plus_lt : forall n1 n2 m,
  n1 + n2 < m ->
  n1 < m /\ n2 < m.
Proof.
(* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 4 stars, standard, optional (more_le_exercises) *)
Theorem leb_complete : forall n m,
  n <=? m = true -> n <= m.
Proof.
  (* FILL IN HERE *) Admitted.

Theorem leb_correct : forall n m,
  n <= m ->
  n <=? m = true.
  (** Hint: May be easiest to prove by induction on [m]. *)
Proof.
  (* FILL IN HERE *) Admitted.

(** Hint: The next two can easily be proved without using [induction]. *)

Theorem leb_iff : forall n m,
  n <=? m = true <-> n <= m.
Proof.
  (* FILL IN HERE *) Admitted.

Theorem leb_true_trans : forall n m o,
  n <=? m = true -> m <=? o = true -> n <=? o = true.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

Module R.

(** **** Exercise: 3 stars, standard, especially useful (R_provability)

    We can define three-place relations, four-place relations,
    etc., in just the same way as binary relations.  For example,
    consider the following three-place relation on numbers: *)

Inductive R : nat -> nat -> nat -> Prop :=
  | c1                                     : R 0     0     0
  | c2 m n o (H : R m     n     o        ) : R (S m) n     (S o)
  | c3 m n o (H : R m     n     o        ) : R m     (S n) (S o)
  | c4 m n o (H : R (S m) (S n) (S (S o))) : R m     n     o
  | c5 m n o (H : R m     n     o        ) : R n     m     o
.

(** - Which of the following propositions are provable?
      - [R 1 1 2] Provable
      - [R 2 2 6] Unprovable

    - If we dropped constructor [c5] from the definition of [R],
      would the set of provable propositions change?  Briefly (1
      sentence) explain your answer.

    - If we dropped constructor [c4] from the definition of [R],
      would the set of provable propositions change?  Briefly (1
      sentence) explain your answer. *)

(* FILL IN HERE *)

(* Do not modify the following line: *)
Definition manual_grade_for_R_provability : option (nat*string) := None.
(** [] *)

(** **** Exercise: 3 stars, standard, optional (R_fact)

    The relation [R] above actually encodes a familiar function.
    Figure out which function; then state and prove this equivalence
    in Coq. *)

Definition fR ( n : nat) ( m : nat) : nat := n + m.  

Search plus.

Theorem R_equiv_fR : forall m n o, R m n o <-> fR m n = o.
Proof.
  intros m n o.
  split.
  - intros R'. induction R' as [|mA nA oA| mB nB oB| mC nC oC | mD nD oD].
    + reflexivity.
    + simpl. rewrite -> IHR'. reflexivity.
    + simpl. unfold fR. unfold fR in IHR'. rewrite <- IHR'. symmetry. apply plus_n_Sm.
    + unfold fR. unfold fR in IHR'. simpl in IHR'. injection IHR' as HR'. rewrite <- plus_n_Sm in HR'. injection HR' as HR. assumption.
    + unfold fR. unfold fR in IHR'. rewrite <- IHR'. apply PeanoNat.Nat.add_comm.
  - intros. rewrite <- H. destruct H.
    induction m.
    +  induction n. apply c1. simpl. apply c3. apply IHn.
    +  induction n. unfold fR. rewrite add_zero. unfold fR in IHm. rewrite add_zero in IHm. apply c2.
       assumption.
       simpl. apply c2. apply IHm.
Qed.
(** [] *)

End R.

(** **** Exercise: 3 stars, advanced (subsequence)

    A list is a _subsequence_ of another list if all of the elements
    in the first list occur in the same order in the second list,
    possibly with some extra elements in between. For example,

      [1;2;3]

    is a subsequence of each of the lists

      [1;2;3]
      [1;1;1;2;2;3]
      [1;2;7;3]
      [5;6;1;9;9;2;7;3;8]

    but it is _not_ a subsequence of any of the lists

      [1;2]
      [1;3]
      [5;6;2;1;7;3;8].

    - Define an inductive proposition [subseq] on [list nat] that
      captures what it means to be a subsequence. (Hint: You'll need
      three cases.)

    - Prove [subseq_refl] that subsequence is reflexive, that is,
      any list is a subsequence of itself.

    - Prove [subseq_app] that for any lists [l1], [l2], and [l3],
      if [l1] is a subsequence of [l2], then [l1] is also a subsequence
      of [l2 ++ l3].
    - (Harder) Prove [subseq_trans] that subsequence is
      transitive -- that is, if [l1] is a subsequence of [l2] and [l2]
      is a subsequence of [l3], then [l1] is a subsequence of [l3]. *)

Inductive subseq : list nat -> list nat -> Prop :=
  | A l : subseq [] l
  | B x l1 l2 (H : subseq l1 l2) : subseq (x :: l1) (x :: l2)
  | C x l1 l2 (H : subseq l1 l2) : subseq l1 (x :: l2).

Check B.
Theorem subseq_refl : forall (l : list nat), subseq l l.
Proof.
  induction l.
  - apply A.
  - apply B. assumption.
Qed.

Theorem subseq_app : forall (l1 l2 l3 : list nat),
  subseq l1 l2 ->
  subseq l1 (l2 ++ l3).
Proof.
  intros.
  induction H as [| x l1 l2 H IH | x' l1' l2' H' IH'].
  - apply A.
  - simpl. apply B. apply IH.
  - simpl. apply C. apply IH'.
Qed.

Theorem subseq_trans : forall (l1 l2 l3 : list nat),
  subseq l1 l2 ->
  subseq l2 l3 ->
  subseq l1 l3.
Proof.
  (* Hint: be careful about what you are doing induction on and which
     other things need to be generalized... *)

  (** Note: the critical thing to observe is that we need to generalize over l1 so that the "induction H2" statement will induct over the second argument rather than the first. This is because our constructors in subseq follow this form, so to apply them, we must have our induction be in the proper formatting. *)
  intros l1 l2 l3 H1 H2.
  generalize dependent l1.
  induction H2 as [| x l l' H IH | x' l1' l2' H' IH'].
  - intros l3 H'. induction l3. apply A. inversion H'.
  - intros l3 H'. inversion H'. apply A. apply B. apply IH. apply H2. apply C. apply IH. apply H2.
  - intros l1 H''. apply C. apply IH'. assumption.
Qed.
(** [] *)

(** **** Exercise: 2 stars, standard, optional (R_provability2)

    Suppose we give Coq the following definition:

    Inductive R : nat -> list nat -> Prop :=
      | c1                    : R 0     []
      | c2 n l (H: R n     l) : R (S n) (n :: l)
      | c3 n l (H: R (S n) l) : R n     l.

    Which of the following propositions are provable?

    - [R 2 [1;0]]
    - [R 1 [1;2;1;0]]
    - [R 6 [3;2;1;0]]  *)

(* FILL IN HERE

    [] *)

(* ################################################################# *)
(** * A Digression on Notation *)

(** There are several equivalent ways of writing inductive
    types.  We've mostly seen this style... *)

Module bin1.
Inductive bin : Type :=
  | Z
  | B0 (n : bin)
  | B1 (n : bin).
End bin1.

(** ... which omits the result types because they are all the same (i.e., [bin]). *)

(** It is completely equivalent to this... *)
Module bin2.
Inductive bin : Type :=
  | Z            : bin
  | B0 (n : bin) : bin
  | B1 (n : bin) : bin.
End bin2.

(** ... where we fill them in, and this... *)

Module bin3.
Inductive bin : Type :=
  | Z : bin
  | B0 : bin -> bin
  | B1 : bin -> bin.
End bin3.

(** ... where we put everything on the right of the colon. *)

(** For inductively defined _propositions_, we need to explicitly give
    the result type for each constructor (because they are not all the
    same), so the first style doesn't make sense, but we can use
    either the second or the third interchangeably. *)

(* ################################################################# *)
(** * Case Study: Regular Expressions *)

(** The [ev] property provides a simple example for
    illustrating inductive definitions and the basic techniques for
    reasoning about them, but it is not terribly exciting -- after
    all, it is equivalent to the two non-inductive definitions of
    evenness that we had already seen, and does not seem to offer any
    concrete benefit over them.

    To give a better sense of the power of inductive definitions, we
    now show how to use them to model a classic concept in computer
    science: _regular expressions_. *)

(** Regular expressions are a simple language for describing sets of
    strings.  Their syntax is defined as follows: *)

Inductive reg_exp (T : Type) : Type :=
  | EmptySet
  | EmptyStr
  | Char (t : T)
  | App (r1 r2 : reg_exp T)
  | Union (r1 r2 : reg_exp T)
  | Star (r : reg_exp T).

Arguments EmptySet {T}.
Arguments EmptyStr {T}.
Arguments Char {T} _.
Arguments App {T} _ _.
Arguments Union {T} _ _.
Arguments Star {T} _.

(** Note that this definition is _polymorphic_: Regular
    expressions in [reg_exp T] describe strings with characters drawn
    from [T] -- that is, lists of elements of [T].

    (Technical aside: We depart slightly from standard practice in
    that we do not require the type [T] to be finite.  This results in
    a somewhat different theory of regular expressions, but the
    difference is not significant for present purposes.) *)

(** We connect regular expressions and strings via the following
    rules, which define when a regular expression _matches_ some
    string:

      - The expression [EmptySet] does not match any string.

      - The expression [EmptyStr] matches the empty string [[]].

      - The expression [Char x] matches the one-character string [[x]].

      - If [re1] matches [s1], and [re2] matches [s2],
        then [App re1 re2] matches [s1 ++ s2].

      - If at least one of [re1] and [re2] matches [s],
        then [Union re1 re2] matches [s].

      - Finally, if we can write some string [s] as the concatenation
        of a sequence of strings [s = s_1 ++ ... ++ s_k], and the
        expression [re] matches each one of the strings [s_i],
        then [Star re] matches [s].

        In particular, the sequence of strings may be empty, so
        [Star re] always matches the empty string [[]] no matter what
        [re] is. *)

(** We can easily translate this informal definition into an
    [Inductive] one as follows.  We use the notation [s =~ re] in
    place of [exp_match s re]. *)

Reserved Notation "s =~ re" (at level 80).

Inductive exp_match {T} : list T -> reg_exp T -> Prop :=
  | MEmpty : [] =~ EmptyStr
  | MChar x : [x] =~ (Char x)
  | MApp s1 re1 s2 re2
             (H1 : s1 =~ re1)
             (H2 : s2 =~ re2)
           : (s1 ++ s2) =~ (App re1 re2)
  | MUnionL s1 re1 re2
                (H1 : s1 =~ re1)
              : s1 =~ (Union re1 re2)
  | MUnionR re1 s2 re2
                (H2 : s2 =~ re2)
              : s2 =~ (Union re1 re2)
  | MStar0 re : [] =~ (Star re)
  | MStarApp s1 s2 re
                 (H1 : s1 =~ re)
                 (H2 : s2 =~ (Star re))
               : (s1 ++ s2) =~ (Star re)

  where "s =~ re" := (exp_match s re).

(** Notice that these rules are not _quite_ the same as the
    informal ones that we gave at the beginning of the section.
    First, we don't need to include a rule explicitly stating that no
    string matches [EmptySet]; we just don't happen to include any
    rule that would have the effect of some string matching
    [EmptySet].  (Indeed, the syntax of inductive definitions doesn't
    even _allow_ us to give such a "negative rule.")

    Second, the informal rules for [Union] and [Star] correspond
    to two constructors each: [MUnionL] / [MUnionR], and [MStar0] /
    [MStarApp].  The result is logically equivalent to the original
    rules but more convenient to use in Coq, since the recursive
    occurrences of [exp_match] are given as direct arguments to the
    constructors, making it easier to perform induction on evidence.
    (The [exp_match_ex1] and [exp_match_ex2] exercises below ask you
    to prove that the constructors given in the inductive declaration
    and the ones that would arise from a more literal transcription of
    the informal rules are indeed equivalent.)

    Let's illustrate these rules with a few examples. *)

Example reg_exp_ex1 : [1] =~ Char 1.
Proof.
  apply MChar.
Qed.


Check MApp.
Check MApp [1].
Example reg_exp_ex2 : [1; 2] =~ App (Char 1) (Char 2).
Proof.
  apply (MApp [1]).
  - apply MChar.
  - apply MChar.
Qed.

(** (Notice how the last example applies [MApp] to the string
    [[1]] directly.  Since the goal mentions [[1; 2]] instead of
    [[1] ++ [2]], Coq wouldn't be able to figure out how to split
    the string on its own.)

    Using [inversion], we can also show that certain strings do _not_
    match a regular expression: *)

Example reg_exp_ex3 : ~ ([1; 2] =~ Char 1).
Proof.
  intros H. inversion H.
Qed.

(** We can define helper functions for writing down regular
    expressions. The [reg_exp_of_list] function constructs a regular
    expression that matches exactly the list that it receives as an
    argument: *)

Fixpoint reg_exp_of_list {T} (l : list T) :=
  match l with
  | [] => EmptyStr
  | x :: l' => App (Char x) (reg_exp_of_list l')
  end.

Example reg_exp_ex4 : [1; 2; 3] =~ reg_exp_of_list [1; 2; 3].
Proof.
  simpl. apply (MApp [1]).
  { apply MChar. }
  apply (MApp [2]).
  { apply MChar. }
  apply (MApp [3]).
  { apply MChar. }
  apply MEmpty.
Qed.

(** We can also prove general facts about [exp_match].  For instance,
    the following lemma shows that every string [s] that matches [re]
    also matches [Star re]. *)

Lemma MStar1 :
  forall T s (re : reg_exp T) ,
    s =~ re ->
    s =~ Star re.
Proof.
  intros T s re H.
  rewrite <- (app_nil_r _ s).
  apply MStarApp.
  - apply H.
  - apply MStar0.
Qed.

(** (Note the use of [app_nil_r] to change the goal of the theorem to
    exactly the shape expected by [MStarApp].) *)

(** **** Exercise: 3 stars, standard (exp_match_ex1)

    The following lemmas show that the informal matching rules given
    at the beginning of the chapter can be obtained from the formal
    inductive definition. *)

Lemma empty_is_empty : forall T (s : list T),
  ~ (s =~ EmptySet).
Proof.
  intros T s. unfold not. intros H. inversion H.
Qed.

Lemma MUnion' : forall T (s : list T) (re1 re2 : reg_exp T),
  s =~ re1 \/ s =~ re2 ->
  s =~ Union re1 re2.
Proof.
  intros T s re1 re2 H.
  destruct H as [HA | HB].
  - apply MUnionL. apply HA.
  - apply MUnionR. apply HB.
Qed.

(** The next lemma is stated in terms of the [fold] function from the
    [Poly] chapter: If [ss : list (list T)] represents a sequence of
    strings [s1, ..., sn], then [fold app ss []] is the result of
    concatenating them all together. *)
Search fold.


Lemma MStar' : forall T (ss : list (list T)) (re : reg_exp T),
  (forall s, In s ss -> s =~ re) ->
  fold app ss [] =~ Star re.
Proof.
  intros T ss re H.
  (** A note to make here is that the main things to attempt before this were.
      1. Induction on Evidence w/ H.
      2. Induction on Evidence w/ re.
      3. Induction on Evidence w/ ss *)
  induction ss as [| h' t' IH].
  - simpl. apply MStar0.
  - simpl. apply MStarApp. apply H. simpl. left. reflexivity.
    simpl. apply IH. intros s H'. apply H.  simpl. right. apply H'.
Qed.
(** [] *)

(** Since the definition of [exp_match] has a recursive
    structure, we might expect that proofs involving regular
    expressions will often require induction on evidence. *)

(** For example, suppose we want to prove the following intuitive
    result: If a regular expression [re] matches some string [s], then
    all elements of [s] must occur as character literals somewhere in
    [re].

    To state this as a theorem, we first define a function [re_chars]
    that lists all characters that occur in a regular expression: *)

Fixpoint re_chars {T} (re : reg_exp T) : list T :=
  match re with
  | EmptySet => []
  | EmptyStr => []
  | Char x => [x]
  | App re1 re2 => re_chars re1 ++ re_chars re2
  | Union re1 re2 => re_chars re1 ++ re_chars re2
  | Star re => re_chars re
  end.

(** The main theorem: *)

Theorem in_re_match : forall T (s : list T) (re : reg_exp T) (x : T),
  s =~ re ->
  In x s ->
  In x (re_chars re).
Proof.
  intros T s re x Hmatch Hin.
  induction Hmatch
    as [| x'
        | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
        | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
        | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2].
  (* WORKED IN CLASS *)
  - (* MEmpty *)
    simpl in Hin. destruct Hin.
  - (* MChar *)
    simpl. simpl in Hin.
    apply Hin.
  - (* MApp *)
    simpl.

(** Something interesting happens in the [MApp] case.  We obtain
    _two_ induction hypotheses: One that applies when [x] occurs in
    [s1] (which matches [re1]), and a second one that applies when [x]
    occurs in [s2] (which matches [re2]). *)

    rewrite In_app_iff in *.
    destruct Hin as [Hin | Hin].
    + (* In x s1 *)
      left. apply (IH1 Hin).
    + (* In x s2 *)
      right. apply (IH2 Hin).
  - (* MUnionL *)
    simpl. rewrite In_app_iff.
    left. apply (IH Hin).
  - (* MUnionR *)
    simpl. rewrite In_app_iff.
    right. apply (IH Hin).
  - (* MStar0 *)
    destruct Hin.
  - (* MStarApp *)
    simpl.

(** Here again we get two induction hypotheses, and they illustrate
    why we need induction on evidence for [exp_match], rather than
    induction on the regular expression [re]: The latter would only
    provide an induction hypothesis for strings that match [re], which
    would not allow us to reason about the case [In x s2]. *)

    rewrite In_app_iff in Hin.
    destruct Hin as [Hin | Hin].
    + (* In x s1 *)
      apply (IH1 Hin).
    + (* In x s2 *)
      apply (IH2 Hin).
Qed.

(** **** Exercise: 4 stars, standard (re_not_empty)

    Write a recursive function [re_not_empty] that tests whether a
    regular expression matches some string. Prove that your function
    is correct. *)

Fixpoint re_not_empty {T : Type} (re : reg_exp T) : bool :=
  match re with
  | EmptySet => false
  | EmptyStr => true
  | Char x => true
  | App re1 re2 => re_not_empty re1 && re_not_empty re2
  | Union re1 re2 => re_not_empty re1 || re_not_empty re2
  | Star re => true
  end.
Lemma re_not_empty_correct : forall T (re : reg_exp T),
    (exists s, s =~ re) <-> re_not_empty re = true.

Proof.
  intros T re.
  split.
    intros H. destruct H as [s H']. induction H'.
  + reflexivity.
  + reflexivity.
  + simpl. rewrite -> IHH'1. rewrite -> IHH'2. reflexivity.
  + simpl. rewrite -> IHH'. reflexivity.
  + simpl. rewrite -> IHH'. symmetry. destruct (re_not_empty re1). reflexivity. reflexivity.
  + simpl. reflexivity.
  + simpl. reflexivity.
  + intros. induction re.
    
  - simpl in H. discriminate H.
  - exists []. apply MEmpty.
  - exists [t]. apply MChar.
  - simpl in H. apply andb_true_iff in H. destruct H as [H1 H2]. apply IHre1 in H1. apply IHre2 in H2.
    destruct H1 as [s1 H']. destruct H2 as [s2 H'']. exists (s1 ++ s2). apply MApp. apply H'. apply H''.
  - simpl in H. apply orb_true_iff in H. destruct H as [H1 | H1].
    apply IHre1 in H1. destruct H1 as [x H1']. exists x. apply MUnionL. apply H1'.
    apply IHre2 in H1. destruct H1 as [x H1']. exists x. apply MUnionR. apply H1'.
  - simpl in H. exists []. apply MStar0.
Qed.
(** [] *)

(* ================================================================= *)
(** ** The [remember] Tactic *)

(** One potentially confusing feature of the [induction] tactic is
    that it will let you try to perform an induction over a term that
    isn't sufficiently general.  The effect of this is to lose
    information (much as [destruct] without an [eqn:] clause can do),
    and leave you unable to complete the proof.  Here's an example: *)

Lemma star_app: forall T (s1 s2 : list T) (re : reg_exp T),
  s1 =~ Star re ->
  s2 =~ Star re ->
  s1 ++ s2 =~ Star re.
Proof.
  intros T s1 s2 re H1.

(** Now, just doing an [inversion] on [H1] won't get us very far in
    the recursive cases. (Try it!). So we need induction (on
    evidence!). Here is a naive first attempt. *)

  induction H1
    as [|x'|s1 re1 s2' re2 Hmatch1 IH1 Hmatch2 IH2
        |s1 re1 re2 Hmatch IH|re1 s2' re2 Hmatch IH
        |re''|s1 s2' re'' Hmatch1 IH1 Hmatch2 IH2].

(** But now, although we get seven cases (as we would expect
    from the definition of [exp_match]), we have lost a very important
    bit of information from [H1]: the fact that [s1] matched something
    of the form [Star re].  This means that we have to give proofs for
    _all_ seven constructors of this definition, even though all but
    two of them ([MStar0] and [MStarApp]) are contradictory.  We can
    still get the proof to go through for a few constructors, such as
    [MEmpty]... *)

  - (* MEmpty *)
    simpl. intros H. apply H.

(** ... but most cases get stuck.  For [MChar], for instance, we
    must show

      s2     =~ Char x' ->
      x'::s2 =~ Char x'

    which is clearly impossible. *)

  - (* MChar. *) intros H. simpl. (* Stuck... *)
Abort.

(** The problem here is that [induction] over a Prop hypothesis
    only works properly with hypotheses that are "completely
    general," i.e., ones in which all the arguments are variable
    as opposed to more complex expressions like [Star re].

    (In this respect, [induction] on evidence behaves more like
    [destruct]-without-[eqn:] than like [inversion].)

    A possible, but awkward, way to solve this problem is "manually
    generalizing" over the problematic expressions by adding
    explicit equality hypotheses to the lemma: *)

Lemma star_app: forall T (s1 s2 : list T) (re re' : reg_exp T),
  re' = Star re ->
  s1 =~ re' ->
  s2 =~ Star re ->
  s1 ++ s2 =~ Star re.

(** We can now proceed by performing induction over evidence
    directly, because the argument to the first hypothesis is
    sufficiently general, which means that we can discharge most cases
    by inverting the [re' = Star re] equality in the context.

    This works, but it makes the statement of the lemma a bit ugly.
    Fortunately, there is a better way... *)
Abort.

(** The tactic [remember e as x] causes Coq to (1) replace all
    occurrences of the expression [e] by the variable [x], and (2) add
    an equation [x = e] to the context.  Here's how we can use it to
    show the above result: *)

Lemma star_app: forall T (s1 s2 : list T) (re : reg_exp T),
  s1 =~ Star re ->
  s2 =~ Star re ->
  s1 ++ s2 =~ Star re.
Proof.
  intros T s1 s2 re H1.
  remember (Star re) as re'.

(** We now have [Heqre' : re' = Star re]. *)

  induction H1
    as [|x'|s1 re1 s2' re2 Hmatch1 IH1 Hmatch2 IH2
        |s1 re1 re2 Hmatch IH|re1 s2' re2 Hmatch IH
        |re''|s1 s2' re'' Hmatch1 IH1 Hmatch2 IH2].

(** The [Heqre'] is contradictory in most cases, allowing us to
    conclude immediately. *)

  - (* MEmpty *)  discriminate.
  - (* MChar *)   discriminate.
  - (* MApp *)    discriminate.
  - (* MUnionL *) discriminate.
  - (* MUnionR *) discriminate.

(** The interesting cases are those that correspond to [Star].  Note
    that the induction hypothesis [IH2] on the [MStarApp] case
    mentions an additional premise [Star re'' = Star re], which
    results from the equality generated by [remember]. *)

  - (* MStar0 *)
    intros H. apply H.

  - (* MStarApp *)
    intros H1. rewrite <- app_assoc.
    apply MStarApp.
    + apply Hmatch1.
    + apply IH2.
      * apply Heqre'.
      * apply H1.
Qed.

(** **** Exercise: 4 stars, standard, optional (exp_match_ex2) *)

(** The [MStar''] lemma below (combined with its converse, the
    [MStar'] exercise above), shows that our definition of [exp_match]
    for [Star] is equivalent to the informal one given previously. *)


Lemma MStar'' : forall T (s : list T) (re : reg_exp T),
  s =~ Star re ->
  exists ss : list (list T),
    s = fold app ss []
    /\ forall s', In s' ss -> s' =~ re.
Proof.
  intros T s re H.
  remember (Star re) as re'.
  induction H as [|x'|s1 re1 s2' re2 Hmatch1 IH1 Hmatch2 IH2
        |s1 re1 re2 Hmatch IH|re1 s2' re2 Hmatch IH
        |re''|s1 s2' re'' Hmatch1 IH1 Hmatch2 IH2].
  - discriminate.
  - discriminate.
  - discriminate.
  - discriminate.
  - discriminate.
  - exists []. simpl. split. reflexivity. intros T' H'. destruct H'.
  - destruct (IH2 Heqre') as [ss' [H1 H2]].
    injection Heqre' as Heqre'. destruct Heqre'.
    exists (s1 :: ss'). split.
    + simpl. rewrite <- H1. reflexivity.
    + intros s' HIn. destruct HIn.
      * rewrite <- H. apply Hmatch1.
      * apply H2 in H. apply H.
Qed.
(** [] *)

(** **** Exercise: 5 stars, advanced (weak_pumping)

    One of the first really interesting theorems in the theory of
    regular expressions is the so-called _pumping lemma_, which
    states, informally, that any sufficiently long string [s] matching
    a regular expression [re] can be "pumped" by repeating some middle
    section of [s] an arbitrary number of times to produce a new
    string also matching [re].  (For the sake of simplicity in this
    exercise, we consider a slightly weaker theorem than is usually
    stated in courses on automata theory -- hence the name
    [weak_pumping].)

    To get started, we need to define "sufficiently long."  Since we
    are working in a constructive logic, we actually need to be able
    to calculate, for each regular expression [re], the minimum length
    for strings [s] to guarantee "pumpability." *)

Module Pumping.

Fixpoint pumping_constant {T} (re : reg_exp T) : nat :=
  match re with
  | EmptySet => 1
  | EmptyStr => 1
  | Char _ => 2
  | App re1 re2 =>
      pumping_constant re1 + pumping_constant re2
  | Union re1 re2 =>
      pumping_constant re1 + pumping_constant re2
  | Star r => pumping_constant r
  end.

(** You may find these lemmas about the pumping constant useful when
    proving the pumping lemma below. *)

Lemma pumping_constant_ge_1 :
  forall T (re : reg_exp T),
    pumping_constant re >= 1.
Proof.
  intros T re. induction re.
  - (* EmptySet *)
    apply le_n.
  - (* EmptyStr *)
    apply le_n.
  - (* Char *)
    apply le_S. apply le_n.
  - (* App *)
    simpl.
    apply le_trans with (n:=pumping_constant re1).
    apply IHre1. apply le_plus_l.
  - (* Union *)
    simpl.
    apply le_trans with (n:=pumping_constant re1).
    apply IHre1. apply le_plus_l.
  - (* Star *)
    simpl. apply IHre.
Qed.

Lemma pumping_constant_0_false :
  forall T (re : reg_exp T),
    pumping_constant re = 0 -> False.
Proof.
  intros T re H.
  assert (Hp1 : pumping_constant re >= 1).
  { apply pumping_constant_ge_1. }
  rewrite H in Hp1. inversion Hp1.
Qed.

(** Next, it is useful to define an auxiliary function that repeats a
    string (appends it to itself) some number of times. *)

Fixpoint napp {T} (n : nat) (l : list T) : list T :=
  match n with
  | 0 => []
  | S n' => l ++ napp n' l
  end.

(** This auxiliary lemma might also be useful in your proof of the
    pumping lemma. *)

Lemma napp_plus: forall T (n m : nat) (l : list T),
  napp (n + m) l = napp n l ++ napp m l.
Proof.
  intros T n m l.
  induction n as [|n IHn].
  - reflexivity.
  - simpl. rewrite IHn, app_assoc. reflexivity.
Qed.

Lemma napp_star :
  forall T m s1 s2 (re : reg_exp T),
    s1 =~ re -> s2 =~ Star re ->
    napp m s1 ++ s2 =~ Star re.
Proof.
  intros T m s1 s2 re Hs1 Hs2.
  induction m.
  - simpl. apply Hs2.
  - simpl. rewrite <- app_assoc.
    apply MStarApp.
    + apply Hs1.
    + apply IHm.
Qed.

(** The (weak) pumping lemma itself says that, if [s =~ re] and if the
    length of [s] is at least the pumping constant of [re], then [s]
    can be split into three substrings [s1 ++ s2 ++ s3] in such a way
    that [s2] can be repeated any number of times and the result, when
    combined with [s1] and [s3], will still match [re].  Since [s2] is
    also guaranteed not to be the empty string, this gives us
    a (constructive!) way to generate strings matching [re] that are
    as long as we like. *)

Lemma weak_pumping : forall T (re : reg_exp T) s,
  s =~ re ->
  pumping_constant re <= length s ->
  exists s1 s2 s3,
    s = s1 ++ s2 ++ s3 /\
    s2 <> [] /\
    forall m, s1 ++ napp m s2 ++ s3 =~ re.

(** Complete the proof below. Several of the lemmas about [le] that
    were in an optional exercise earlier in this chapter may also be
    useful. *)
Proof.
  intros T re s Hmatch.
  induction Hmatch
    as [ | x | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
       | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
       | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2 ].
  - (* MEmpty *)
    simpl. intros contra. inversion contra.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 5 stars, advanced, optional (pumping)

    Now here is the usual version of the pumping lemma. In addition to
    requiring that [s2 <> []], it also requires that [length s1 +
    length s2 <= pumping_constant re]. *)

Lemma pumping : forall T (re : reg_exp T) s,
  s =~ re ->
  pumping_constant re <= length s ->
  exists s1 s2 s3,
    s = s1 ++ s2 ++ s3 /\
    s2 <> [] /\
    length s1 + length s2 <= pumping_constant re /\
    forall m, s1 ++ napp m s2 ++ s3 =~ re.

(** You may want to copy your proof of weak_pumping below. *)
Proof.
  intros T re s Hmatch.
  induction Hmatch
    as [ | x | s1 re1 s2 re2 Hmatch1 IH1 Hmatch2 IH2
       | s1 re1 re2 Hmatch IH | re1 s2 re2 Hmatch IH
       | re | s1 s2 re Hmatch1 IH1 Hmatch2 IH2 ].
  - (* MEmpty *)
    simpl. intros contra. inversion contra.
  (* FILL IN HERE *) Admitted.

End Pumping.
(** [] *)

(* ################################################################# *)
(** * Case Study: Improving Reflection *)

(** We've seen in the [Logic] chapter that we sometimes
    need to relate boolean computations to statements in [Prop].  But
    performing this conversion as we did there can result in tedious
    proof scripts.  Consider the proof of the following theorem: *)

Theorem filter_not_empty_In : forall n l,
  filter (fun x => n =? x) l <> [] ->
  In n l.
Proof.
  intros n l. induction l as [|m l' IHl'].
  - (* l = [] *)
    simpl. intros H. apply H. reflexivity.
  - (* l = m :: l' *)
    simpl. destruct (n =? m) eqn:H.
    + (* n =? m = true *)
      intros _. rewrite eqb_eq in H. rewrite H.
      left. reflexivity.
    + (* n =? m = false *)
      intros H'. right. apply IHl'. apply H'.
Qed.

(** In the first branch after [destruct], we explicitly apply
    the [eqb_eq] lemma to the equation generated by
    destructing [n =? m], to convert the assumption [n =? m
    = true] into the assumption [n = m]; then we had to [rewrite]
    using this assumption to complete the case. *)

(** We can streamline this sort of reasoning by defining an inductive
    proposition that yields a better case-analysis principle for [n =?
    m].  Instead of generating the assumption [(n =? m) = true], which
    usually requires some massaging before we can use it, this
    principle gives us right away the assumption we really need: [n =
    m].

    Following the terminology introduced in [Logic], we call this
    the "reflection principle for equality on numbers," and we say
    that the boolean [n =? m] is _reflected in_ the proposition [n =
    m]. *)

Inductive reflect (P : Prop) : bool -> Prop :=
  | ReflectT (H :   P) : reflect P true
  | ReflectF (H : ~ P) : reflect P false.

(** The [reflect] property takes two arguments: a proposition
    [P] and a boolean [b].  It states that the property [P]
    _reflects_ (intuitively, is equivalent to) the boolean [b]: that
    is, [P] holds if and only if [b = true].

    To see this, notice that, by definition, the only way we can
    produce evidence for [reflect P true] is by showing [P] and then
    using the [ReflectT] constructor.  If we invert this statement,
    this means that we can extract evidence for [P] from a proof of
    [reflect P true].

    Similarly, the only way to show [reflect P false] is by tagging
    evidence for [~ P] with the [ReflectF] constructor. *)

(** To put this observation to work, we first prove that the
    statements [P <-> b = true] and [reflect P b] are indeed
    equivalent.  First, the left-to-right implication: *)

Theorem iff_reflect : forall P b, (P <-> b = true) -> reflect P b.
Proof.
  (* WORKED IN CLASS *)
  intros P b H. destruct b eqn:Eb.
  - apply ReflectT. rewrite H. reflexivity.
  - apply ReflectF. rewrite H. intros H'. discriminate.
Qed.

(** Now you prove the right-to-left implication: *)

(** **** Exercise: 2 stars, standard, especially useful (reflect_iff) *)
Theorem reflect_iff : forall P b, reflect P b -> (P <-> b = true).
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** We can think of [reflect] as a variant of the usual "if and only
    if" connective; the advantage of [reflect] is that, by destructing
    a hypothesis or lemma of the form [reflect P b], we can perform
    case analysis on [b] while _at the same time_ generating
    appropriate hypothesis in the two branches ([P] in the first
    subgoal and [~ P] in the second). *)

(** Let's use [reflect] to produce a smoother proof of
    [filter_not_empty_In].

    We begin by recasting the [eqb_eq] lemma in terms of [reflect]: *)

Lemma eqbP : forall n m, reflect (n = m) (n =? m).
Proof.
  intros n m. apply iff_reflect. rewrite eqb_eq. reflexivity.
Qed.

(** The proof of [filter_not_empty_In] now goes as follows.  Notice
    how the calls to [destruct] and [rewrite] in the earlier proof of
    this theorem are combined here into a single call to
    [destruct]. *)

(** (To see this clearly, execute the two proofs of
    [filter_not_empty_In] with Coq and observe the differences in
    proof state at the beginning of the first case of the
    [destruct].) *)

Theorem filter_not_empty_In' : forall n l,
  filter (fun x => n =? x) l <> [] ->
  In n l.
Proof.
  intros n l. induction l as [|m l' IHl'].
  - (* l = [] *)
    simpl. intros H. apply H. reflexivity.
  - (* l = m :: l' *)
    simpl. destruct (eqbP n m) as [H | H].
    + (* n = m *)
      intros _. rewrite H. left. reflexivity.
    + (* n <> m *)
      intros H'. right. apply IHl'. apply H'.
Qed.

(** **** Exercise: 3 stars, standard, especially useful (eqbP_practice)

    Use [eqbP] as above to prove the following: *)

Fixpoint count n l :=
  match l with
  | [] => 0
  | m :: l' => (if n =? m then 1 else 0) + count n l'
  end.

Theorem eqbP_practice : forall n l,
  count n l = 0 -> ~(In n l).
Proof.
  intros n l Hcount. induction l as [| m l' IHl'].
  (* FILL IN HERE *) Admitted.
(** [] *)

(** This small example shows reflection giving us a small gain in
    convenience; in larger developments, using [reflect] consistently
    can often lead to noticeably shorter and clearer proof scripts.
    We'll see many more examples in later chapters and in _Programming
    Language Foundations_.

    This way of using [reflect] was popularized by _SSReflect_, a Coq
    library that has been used to formalize important results in
    mathematics, including the 4-color theorem and the Feit-Thompson
    theorem.  The name SSReflect stands for _small-scale reflection_,
    i.e., the pervasive use of reflection to streamline small proof
    steps by turning them into boolean computations. *)

(* ################################################################# *)
(** * Additional Exercises *)

(** **** Exercise: 3 stars, standard, especially useful (nostutter_defn)

    Formulating inductive definitions of properties is an important
    skill you'll need in this course.  Try to solve this exercise
    without any help.

    We say that a list "stutters" if it repeats the same element
    consecutively.  (This is different from not containing duplicates:
    the sequence [[1;4;1]] has two occurrences of the element [1] but
    does not stutter.)  The property "[nostutter mylist]" means that
    [mylist] does not stutter.  Formulate an inductive definition for
    [nostutter]. *)

Inductive nostutter {X:Type} : list X -> Prop :=
 (* FILL IN HERE *)
.
(** Make sure each of these tests succeeds, but feel free to change
    the suggested proof (in comments) if the given one doesn't work
    for you.  Your definition might be different from ours and still
    be correct, in which case the examples might need a different
    proof.  (You'll notice that the suggested proofs use a number of
    tactics we haven't talked about, to make them more robust to
    different possible ways of defining [nostutter].  You can probably
    just uncomment and use them as-is, but you can also prove each
    example with more basic tactics.)  *)

Example test_nostutter_1: nostutter [3;1;4;1;5;6].
(* FILL IN HERE *) Admitted.
(* 
  Proof. repeat constructor; apply eqb_neq; auto.
  Qed.
*)

Example test_nostutter_2:  nostutter (@nil nat).
(* FILL IN HERE *) Admitted.
(* 
  Proof. repeat constructor; apply eqb_neq; auto.
  Qed.
*)

Example test_nostutter_3:  nostutter [5].
(* FILL IN HERE *) Admitted.
(* 
  Proof. repeat constructor; auto. Qed.
*)

Example test_nostutter_4:      not (nostutter [3;1;1;4]).
(* FILL IN HERE *) Admitted.
(* 
  Proof. intro.
  repeat match goal with
    h: nostutter _ |- _ => inversion h; clear h; subst
  end.
  contradiction; auto. Qed.
*)

(* Do not modify the following line: *)
Definition manual_grade_for_nostutter : option (nat*string) := None.
(** [] *)

(** **** Exercise: 4 stars, advanced (filter_challenge)

    Let's prove that our definition of [filter] from the [Poly]
    chapter matches an abstract specification.  Here is the
    specification, written out informally in English:

    A list [l] is an "in-order merge" of [l1] and [l2] if it contains
    all the same elements as [l1] and [l2], in the same order as [l1]
    and [l2], but possibly interleaved.  For example,

    [1;4;6;2;3]

    is an in-order merge of

    [1;6;2]

    and

    [4;3].

    Now, suppose we have a set [X], a function [test: X->bool], and a
    list [l] of type [list X].  Suppose further that [l] is an
    in-order merge of two lists, [l1] and [l2], such that every item
    in [l1] satisfies [test] and no item in [l2] satisfies test.  Then
    [filter test l = l1].

    First define what it means for one list to be a merge of two
    others.  Do this with an inductive relation, not a [Fixpoint].  *)

Inductive merge {X:Type} : list X -> list X -> list X -> Prop :=
(* FILL IN HERE *)
.

Theorem merge_filter : forall (X : Set) (test: X->bool) (l l1 l2 : list X),
  merge l1 l2 l ->
  All (fun n => test n = true) l1 ->
  All (fun n => test n = false) l2 ->
  filter test l = l1.
Proof.
  (* FILL IN HERE *) Admitted.

(* FILL IN HERE *)

(** [] *)

(** **** Exercise: 5 stars, advanced, optional (filter_challenge_2)

    A different way to characterize the behavior of [filter] goes like
    this: Among all subsequences of [l] with the property that [test]
    evaluates to [true] on all their members, [filter test l] is the
    longest.  Formalize this claim and prove it. *)

(* FILL IN HERE

    [] *)

(** **** Exercise: 4 stars, standard, optional (palindromes)

    A palindrome is a sequence that reads the same backwards as
    forwards.

    - Define an inductive proposition [pal] on [list X] that
      captures what it means to be a palindrome. (Hint: You'll need
      three cases.  Your definition should be based on the structure
      of the list; just having a single constructor like

        c : forall l, l = rev l -> pal l

      may seem obvious, but will not work very well.)

    - Prove ([pal_app_rev]) that

       forall l, pal (l ++ rev l).

    - Prove ([pal_rev] that)

       forall l, pal l -> l = rev l.
*)

Inductive pal {X:Type} : list X -> Prop :=
(* FILL IN HERE *)
.

Theorem pal_app_rev : forall (X:Type) (l : list X),
  pal (l ++ (rev l)).
Proof.
  (* FILL IN HERE *) Admitted.

Theorem pal_rev : forall (X:Type) (l: list X) , pal l -> l = rev l.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 5 stars, standard, optional (palindrome_converse)

    Again, the converse direction is significantly more difficult, due
    to the lack of evidence.  Using your definition of [pal] from the
    previous exercise, prove that

     forall l, l = rev l -> pal l.
*)

Theorem palindrome_converse: forall {X: Type} (l: list X),
    l = rev l -> pal l.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 4 stars, advanced, optional (NoDup)

    Recall the definition of the [In] property from the [Logic]
    chapter, which asserts that a value [x] appears at least once in a
    list [l]: *)

(* Fixpoint In (A : Type) (x : A) (l : list A) : Prop :=
   match l with
   | [] => False
   | x' :: l' => x' = x \/ In A x l'
   end *)

(** Your first task is to use [In] to define a proposition [disjoint X
    l1 l2], which should be provable exactly when [l1] and [l2] are
    lists (with elements of type X) that have no elements in
    common. *)

(* FILL IN HERE *)

(** Next, use [In] to define an inductive proposition [NoDup X
    l], which should be provable exactly when [l] is a list (with
    elements of type [X]) where every member is different from every
    other.  For example, [NoDup nat [1;2;3;4]] and [NoDup
    bool []] should be provable, while [NoDup nat [1;2;1]] and
    [NoDup bool [true;true]] should not be.  *)

(* FILL IN HERE *)

(** Finally, state and prove one or more interesting theorems relating
    [disjoint], [NoDup] and [++] (list append).  *)

(* FILL IN HERE *)

(* Do not modify the following line: *)
Definition manual_grade_for_NoDup_disjoint_etc : option (nat*string) := None.
(** [] *)

(** **** Exercise: 4 stars, advanced, optional (pigeonhole_principle)

    The _pigeonhole principle_ states a basic fact about counting: if
    we distribute more than [n] items into [n] pigeonholes, some
    pigeonhole must contain at least two items.  As often happens, this
    apparently trivial fact about numbers requires non-trivial
    machinery to prove, but we now have enough... *)

(** First prove an easy and useful lemma. *)

Lemma in_split : forall (X:Type) (x:X) (l:list X),
  In x l ->
  exists l1 l2, l = l1 ++ x :: l2.
Proof.
  (* FILL IN HERE *) Admitted.

(** Now define a property [repeats] such that [repeats X l] asserts
    that [l] contains at least one repeated element (of type [X]).  *)

Inductive repeats {X:Type} : list X -> Prop :=
  (* FILL IN HERE *)
.

(* Do not modify the following line: *)
Definition manual_grade_for_check_repeats : option (nat*string) := None.

(** Now, here's a way to formalize the pigeonhole principle.  Suppose
    list [l2] represents a list of pigeonhole labels, and list [l1]
    represents the labels assigned to a list of items.  If there are
    more items than labels, at least two items must have the same
    label -- i.e., list [l1] must contain repeats.

    This proof is much easier if you use the [excluded_middle]
    hypothesis to show that [In] is decidable, i.e., [forall x l, (In x
    l) \/ ~ (In x l)].  However, it is also possible to make the proof
    go through _without_ assuming that [In] is decidable; if you
    manage to do this, you will not need the [excluded_middle]
    hypothesis. *)
Theorem pigeonhole_principle: excluded_middle ->
  forall (X:Type) (l1  l2:list X),
  (forall x, In x l1 -> In x l2) ->
  length l2 < length l1 ->
  repeats l1.
Proof.
  intros EM X l1. induction l1 as [|x l1' IHl1'].
  (* FILL IN HERE *) Admitted.
(** [] *)

(* ================================================================= *)
(** ** Extended Exercise: A Verified Regular-Expression Matcher *)

(** We have now defined a match relation over regular expressions and
    polymorphic lists. We can use such a definition to manually prove that
    a given regex matches a given string, but it does not give us a
    program that we can run to determine a match automatically.

    It would be reasonable to hope that we can translate the definitions
    of the inductive rules for constructing evidence of the match relation
    into cases of a recursive function that reflects the relation by recursing
    on a given regex. However, it does not seem straightforward to define
    such a function in which the given regex is a recursion variable
    recognized by Coq. As a result, Coq will not accept that the function
    always terminates.

    Heavily-optimized regex matchers match a regex by translating a given
    regex into a state machine and determining if the state machine
    accepts a given string. However, regex matching can also be
    implemented using an algorithm that operates purely on strings and
    regexes without defining and maintaining additional datatypes, such as
    state machines. We'll implement such an algorithm, and verify that
    its value reflects the match relation. *)

(** We will implement a regex matcher that matches strings represented
    as lists of ASCII characters: *)
Require Import Coq.Strings.Ascii.

Definition string := list ascii.

(** The Coq standard library contains a distinct inductive definition
    of strings of ASCII characters. However, we will use the above
    definition of strings as lists as ASCII characters in order to apply
    the existing definition of the match relation.

    We could also define a regex matcher over polymorphic lists, not lists
    of ASCII characters specifically. The matching algorithm that we will
    implement needs to be able to test equality of elements in a given
    list, and thus needs to be given an equality-testing
    function. Generalizing the definitions, theorems, and proofs that we
    define for such a setting is a bit tedious, but workable. *)

(** The proof of correctness of the regex matcher will combine
    properties of the regex-matching function with properties of the
    [match] relation that do not depend on the matching function. We'll go
    ahead and prove the latter class of properties now. Most of them have
    straightforward proofs, which have been given to you, although there
    are a few key lemmas that are left for you to prove. *)

(** Each provable [Prop] is equivalent to [True]. *)
Lemma provable_equiv_true : forall (P : Prop), P -> (P <-> True).
Proof.
  intros.
  split.
  - intros. constructor.
  - intros _. apply H.
Qed.

(** Each [Prop] whose negation is provable is equivalent to [False]. *)
Lemma not_equiv_false : forall (P : Prop), ~P -> (P <-> False).
Proof.
  intros.
  split.
  - apply H.
  - intros. destruct H0.
Qed.

(** [EmptySet] matches no string. *)
Lemma null_matches_none : forall (s : string), (s =~ EmptySet) <-> False.
Proof.
  intros.
  apply not_equiv_false.
  unfold not. intros. inversion H.
Qed.

(** [EmptyStr] only matches the empty string. *)
Lemma empty_matches_eps : forall (s : string), s =~ EmptyStr <-> s = [ ].
Proof.
  split.
  - intros. inversion H. reflexivity.
  - intros. rewrite H. apply MEmpty.
Qed.

(** [EmptyStr] matches no non-empty string. *)
Lemma empty_nomatch_ne : forall (a : ascii) s, (a :: s =~ EmptyStr) <-> False.
Proof.
  intros.
  apply not_equiv_false.
  unfold not. intros. inversion H.
Qed.

(** [Char a] matches no string that starts with a non-[a] character. *)
Lemma char_nomatch_char :
  forall (a b : ascii) s, b <> a -> (b :: s =~ Char a <-> False).
Proof.
  intros.
  apply not_equiv_false.
  unfold not.
  intros.
  apply H.
  inversion H0.
  reflexivity.
Qed.

(** If [Char a] matches a non-empty string, then the string's tail is empty. *)
Lemma char_eps_suffix : forall (a : ascii) s, a :: s =~ Char a <-> s = [ ].
Proof.
  split.
  - intros. inversion H. reflexivity.
  - intros. rewrite H. apply MChar.
Qed.

(** [App re0 re1] matches string [s] iff [s = s0 ++ s1], where [s0]
    matches [re0] and [s1] matches [re1]. *)
Lemma app_exists : forall (s : string) re0 re1,
  s =~ App re0 re1 <->
  exists s0 s1, s = s0 ++ s1 /\ s0 =~ re0 /\ s1 =~ re1.
Proof.
  intros.
  split.
  - intros. inversion H. exists s1, s2. split.
    * reflexivity.
    * split. apply H3. apply H4.
  - intros [ s0 [ s1 [ Happ [ Hmat0 Hmat1 ] ] ] ].
    rewrite Happ. apply (MApp s0 _ s1 _ Hmat0 Hmat1).
Qed.

(** **** Exercise: 3 stars, standard, optional (app_ne)

    [App re0 re1] matches [a::s] iff [re0] matches the empty string
    and [a::s] matches [re1] or [s=s0++s1], where [a::s0] matches [re0]
    and [s1] matches [re1].

    Even though this is a property of purely the match relation, it is a
    critical observation behind the design of our regex matcher. So (1)
    take time to understand it, (2) prove it, and (3) look for how you'll
    use it later. *)
Lemma app_ne : forall (a : ascii) s re0 re1,
  a :: s =~ (App re0 re1) <->
  ([ ] =~ re0 /\ a :: s =~ re1) \/
  exists s0 s1, s = s0 ++ s1 /\ a :: s0 =~ re0 /\ s1 =~ re1.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** [s] matches [Union re0 re1] iff [s] matches [re0] or [s] matches [re1]. *)
Lemma union_disj : forall (s : string) re0 re1,
  s =~ Union re0 re1 <-> s =~ re0 \/ s =~ re1.
Proof.
  intros. split.
  - intros. inversion H.
    + left. apply H2.
    + right. apply H1.
  - intros [ H | H ].
    + apply MUnionL. apply H.
    + apply MUnionR. apply H.
Qed.

(** **** Exercise: 3 stars, standard, optional (star_ne)

    [a::s] matches [Star re] iff [s = s0 ++ s1], where [a::s0] matches
    [re] and [s1] matches [Star re]. Like [app_ne], this observation is
    critical, so understand it, prove it, and keep it in mind.

    Hint: you'll need to perform induction. There are quite a few
    reasonable candidates for [Prop]'s to prove by induction. The only one
    that will work is splitting the [iff] into two implications and
    proving one by induction on the evidence for [a :: s =~ Star re]. The
    other implication can be proved without induction.

    In order to prove the right property by induction, you'll need to
    rephrase [a :: s =~ Star re] to be a [Prop] over general variables,
    using the [remember] tactic.  *)

Lemma star_ne : forall (a : ascii) s re,
  a :: s =~ Star re <->
  exists s0 s1, s = s0 ++ s1 /\ a :: s0 =~ re /\ s1 =~ Star re.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** The definition of our regex matcher will include two fixpoint
    functions. The first function, given regex [re], will evaluate to a
    value that reflects whether [re] matches the empty string. The
    function will satisfy the following property: *)
Definition refl_matches_eps m :=
  forall re : reg_exp ascii, reflect ([ ] =~ re) (m re).

(** **** Exercise: 2 stars, standard, optional (match_eps)

    Complete the definition of [match_eps] so that it tests if a given
    regex matches the empty string: *)
Fixpoint match_eps (re: reg_exp ascii) : bool
  (* REPLACE THIS LINE WITH ":= _your_definition_ ." *). Admitted.
(** [] *)

(** **** Exercise: 3 stars, standard, optional (match_eps_refl)

    Now, prove that [match_eps] indeed tests if a given regex matches
    the empty string.  (Hint: You'll want to use the reflection lemmas
    [ReflectT] and [ReflectF].) *)
Lemma match_eps_refl : refl_matches_eps match_eps.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** We'll define other functions that use [match_eps]. However, the
    only property of [match_eps] that you'll need to use in all proofs
    over these functions is [match_eps_refl]. *)

(** The key operation that will be performed by our regex matcher will
    be to iteratively construct a sequence of regex derivatives. For each
    character [a] and regex [re], the derivative of [re] on [a] is a regex
    that matches all suffixes of strings matched by [re] that start with
    [a]. I.e., [re'] is a derivative of [re] on [a] if they satisfy the
    following relation: *)

Definition is_der re (a : ascii) re' :=
  forall s, a :: s =~ re <-> s =~ re'.

(** A function [d] derives strings if, given character [a] and regex
    [re], it evaluates to the derivative of [re] on [a]. I.e., [d]
    satisfies the following property: *)
Definition derives d := forall a re, is_der re a (d a re).

(** **** Exercise: 3 stars, standard, optional (derive)

    Define [derive] so that it derives strings. One natural
    implementation uses [match_eps] in some cases to determine if key
    regex's match the empty string. *)
Fixpoint derive (a : ascii) (re : reg_exp ascii) : reg_exp ascii
  (* REPLACE THIS LINE WITH ":= _your_definition_ ." *). Admitted.
(** [] *)

(** The [derive] function should pass the following tests. Each test
    establishes an equality between an expression that will be
    evaluated by our regex matcher and the final value that must be
    returned by the regex matcher. Each test is annotated with the
    match fact that it reflects. *)
Example c := ascii_of_nat 99.
Example d := ascii_of_nat 100.

(** "c" =~ EmptySet: *)
Example test_der0 : match_eps (derive c (EmptySet)) = false.
Proof.
  (* FILL IN HERE *) Admitted.

(** "c" =~ Char c: *)
Example test_der1 : match_eps (derive c (Char c)) = true.
Proof.
  (* FILL IN HERE *) Admitted.

(** "c" =~ Char d: *)
Example test_der2 : match_eps (derive c (Char d)) = false.
Proof.
  (* FILL IN HERE *) Admitted.

(** "c" =~ App (Char c) EmptyStr: *)
Example test_der3 : match_eps (derive c (App (Char c) EmptyStr)) = true.
Proof.
  (* FILL IN HERE *) Admitted.

(** "c" =~ App EmptyStr (Char c): *)
Example test_der4 : match_eps (derive c (App EmptyStr (Char c))) = true.
Proof.
  (* FILL IN HERE *) Admitted.

(** "c" =~ Star c: *)
Example test_der5 : match_eps (derive c (Star (Char c))) = true.
Proof.
  (* FILL IN HERE *) Admitted.

(** "cd" =~ App (Char c) (Char d): *)
Example test_der6 :
  match_eps (derive d (derive c (App (Char c) (Char d)))) = true.
Proof.
  (* FILL IN HERE *) Admitted.

(** "cd" =~ App (Char d) (Char c): *)
Example test_der7 :
  match_eps (derive d (derive c (App (Char d) (Char c)))) = false.
Proof.
  (* FILL IN HERE *) Admitted.

(** **** Exercise: 4 stars, standard, optional (derive_corr)

    Prove that [derive] in fact always derives strings.

    Hint: one proof performs induction on [re], although you'll need
    to carefully choose the property that you prove by induction by
    generalizing the appropriate terms.

    Hint: if your definition of [derive] applies [match_eps] to a
    particular regex [re], then a natural proof will apply
    [match_eps_refl] to [re] and destruct the result to generate cases
    with assumptions that the [re] does or does not match the empty
    string.

    Hint: You can save quite a bit of work by using lemmas proved
    above. In particular, to prove many cases of the induction, you
    can rewrite a [Prop] over a complicated regex (e.g., [s =~ Union
    re0 re1]) to a Boolean combination of [Prop]'s over simple
    regex's (e.g., [s =~ re0 \/ s =~ re1]) using lemmas given above
    that are logical equivalences. You can then reason about these
    [Prop]'s naturally using [intro] and [destruct]. *)
Lemma derive_corr : derives derive.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(** We'll define the regex matcher using [derive]. However, the only
    property of [derive] that you'll need to use in all proofs of
    properties of the matcher is [derive_corr]. *)

(** A function [m] _matches regexes_ if, given string [s] and regex [re],
    it evaluates to a value that reflects whether [s] is matched by
    [re]. I.e., [m] holds the following property: *)
Definition matches_regex m : Prop :=
  forall (s : string) re, reflect (s =~ re) (m s re).

(** **** Exercise: 2 stars, standard, optional (regex_match)

    Complete the definition of [regex_match] so that it matches
    regexes. *)
Fixpoint regex_match (s : string) (re : reg_exp ascii) : bool
  (* REPLACE THIS LINE WITH ":= _your_definition_ ." *). Admitted.
(** [] *)

(** **** Exercise: 3 stars, standard, optional (regex_match_correct)

    Finally, prove that [regex_match] in fact matches regexes.

    Hint: if your definition of [regex_match] applies [match_eps] to
    regex [re], then a natural proof applies [match_eps_refl] to [re]
    and destructs the result to generate cases in which you may assume
    that [re] does or does not match the empty string.

    Hint: if your definition of [regex_match] applies [derive] to
    character [x] and regex [re], then a natural proof applies
    [derive_corr] to [x] and [re] to prove that [x :: s =~ re] given
    [s =~ derive x re], and vice versa. *)
Theorem regex_match_correct : matches_regex regex_match.
Proof.
  (* FILL IN HERE *) Admitted.
(** [] *)

(* 2023-10-03 16:40 *)
.
Proof.
  intros.
    
Qed.
(* Do not modify the following line: *)
Definition manual_grade_for_pumping_redux : option (nat*string) := None.
(** [] *)

(** **** Exercise: 3 stars, advanced, optional (pumping_redux_strong)

    Use [auto], [lia], and any other useful tactics from this chapter
    to shorten your proof (or the "official" solution proof) of the
    stronger Pumping Lemma exercise from [IndProp]. *)

Lemma pumping : forall T (re : reg_exp T) s,
    s =~ re ->
    pumping_constant re <= length s ->
    exists s1 s2 s3,
      s = s1 ++ s2 ++ s3 /\
        s2 <> [] /\
        length s1 + length s2 <= pumping_constant re /\
        forall m, s1 ++ napp m s2 ++ s3 =~ re.

Proof.
(* FILL IN HERE *) Admitted.
(* Do not modify the following line: *)
Definition manual_grade_for_pumping_redux_strong : option (nat*string) := None.
(** [] *)

(* ================================================================= *)
(** ** The [eauto] variant *)

(** There is a variant of [auto] (and other tactics, such as
    [apply]) that makes it possible to delay instantiation of
    quantifiers. To motivate this feature, consider again this simple
    example: *)

Example trans_example1:  forall a b c d,
    a <= b + b * c  ->
    (1 + c) * b <= d ->
    a <= d.
Proof.
  intros a b c d H1 H2.
  apply le_trans with (b + b * c).
    (* ^ We must supply the intermediate value *)
  - apply H1.
  - simpl in H2. rewrite mul_comm. apply H2.
Qed.

(** In the first step of the proof, we had to explicitly provide a
    longish expression to help Coq instantiate a "hidden" argument to
    the [le_trans] constructor. This was needed because the definition
    of [le_trans]...

    le_trans : forall m n o : nat, m <= n -> n <= o -> m <= o

    is quantified over a variable, [n], that does not appear in its
    conclusion, so unifying its conclusion with the goal state doesn't
    help Coq find a suitable value for this variable.  If we leave
    out the [with], this step fails ("Error: Unable to find an
    instance for the variable [n]").

    We already know one way to avoid an explicit [with] clause, namely
    to provide [H1] as the (first) explicit argument to [le_trans].
    But here's another way, using the [eapply tactic]: *)

Example trans_example1':  forall a b c d,
    a <= b + b * c  ->
    (1 + c) * b <= d ->
    a <= d.
Proof.
  intros a b c d H1 H2.
  eapply le_trans. (* 1 *)
  - apply H1. (* 2 *)
  - simpl in H2. rewrite mul_comm. apply H2.
Qed.

(** The [eapply H] tactic behaves just like [apply H] except
    that, after it finishes unifying the goal state with the
    conclusion of [H], it does not bother to check whether all the
    variables that were introduced in the process have been given
    concrete values during unification.

    If you step through the proof above, you'll see that the goal
    state at position [1] mentions the _existential variable_ [?n] in
    both of the generated subgoals.  The next step (which gets us to
    position [2]) replaces [?n] with a concrete value.  When we start
    working on the second subgoal (position [3]), we observe that the
    occurrence of [?n] in this subgoal has been replaced by the value
    that it was given during the first subgoal. *)

(** Several of the tactics that we've seen so far, including
    [exists], [constructor], and [auto], have [e...] variants.  For
    example, here's a proof using [eauto]: *)

Example trans_example2:  forall a b c d,
    a <= b + b * c  ->
    b + b * c <= d ->
    a <= d.
Proof.
  intros a b c d H1 H2.
  info_eauto using le_trans.
Qed.

(** The [eauto] tactic works just like [auto], except that it
    uses [eapply] instead of [apply].

    Pro tip: One might think that, since [eapply] and [eauto] are more
    powerful than [apply] and [auto], it would be a good idea to use
    them all the time.  Unfortunately, they are also significantly
    slower -- especially [eauto].  Coq experts tend to use [apply] and
    [auto] most of the time, only switching to the [e] variants when
    the ordinary variants don't do the job. *)

(* ################################################################# *)
(** * Ltac: The Tactic Language *)

(** Most of the tactics we have been using are implemented in
    OCaml, where they are able to use an API to access Coq's internal
    structures at a low level. But this is seldom worth the trouble
    for ordinary Coq users.

    Coq has a high-level language called Ltac for programming new
    tactics in Coq itself, without having to escape to OCaml.
    Actually we've been using Ltac all along -- anytime we are in
    proof mode, we've been writing Ltac programs. At their most basic,
    those programs are just invocations of built-in tactics.  The
    tactical constructs we learned at the beginning of this chapter
    are also part of Ltac.

    What we turn to, next, is ways to use Ltac to reduce the amount of
    proof script we have to write ourselves. *)

(* ================================================================= *)
(** ** Ltac Functions *)

(** Here is a simple [Ltac] example: *)

Ltac simpl_and_try tac := simpl; try tac.

(** This defines a new tactic called [simpl_and_try] that takes one
    tactic [tac] as an argument and is defined to be equivalent to
    [simpl; try tac]. Now writing "[simpl_and_try reflexivity.]" in a
    proof will be the same as writing "[simpl; try reflexivity.]" *)

Example sat_ex1 : 1 + 1 = 2.
Proof. simpl_and_try reflexivity. Qed.

Example sat_ex2 : forall (n : nat), 1 - 1 + n + 1 = 1 + n.
Proof. simpl_and_try reflexivity. lia. Qed.

(** Of course, that little tactic is not so useful. But it
    demonstrates that we can parameterize Ltac-defined tactics, and
    that their bodies are themselves tactics that will be run in the
    context of a proof. So Ltac can be used to create functions on
    tactics. *)

(** For a more useful tactic, consider these three proofs from
    [Basics], and how structurally similar they all are: *)

Theorem plus_1_neq_0 : forall n : nat,
  (n + 1) =? 0 = false.
Proof.
  intros n. destruct n.
  - reflexivity.
  - reflexivity.
Qed.

Theorem negb_involutive : forall b : bool,
  negb (negb b) = b.
Proof.
  intros b. destruct b.
  - reflexivity.
  - reflexivity.
Qed.

Theorem andb_commutative : forall b c, andb b c = andb c b.
Proof.
  intros b c. destruct b.
  - destruct c.
    + reflexivity.
    + reflexivity.
  - destruct c.
    + reflexivity.
    + reflexivity.
Qed.

(** We can factor out the common structure:

    - Do a destruct.

    - For each branch, finish with [reflexivity] -- if possible. *)

Ltac destructpf x :=
  destruct x; try reflexivity.

Theorem plus_1_neq_0' : forall n : nat,
    (n + 1) =? 0 = false.
Proof. intros n; destructpf n. Qed.

Theorem negb_involutive' : forall b : bool,
  negb (negb b) = b.
Proof. intros b; destructpf b. Qed.

Theorem andb_commutative' : forall b c, andb b c = andb c b.
Proof.
  intros b c; destructpf b; destructpf c.
Qed.

(** **** Exercise: 1 star, standard (andb3_exchange)

    Re-prove the following theorem from [Basics], using only
    [intros] and [destructpf]. You should have a one-shot proof. *)

Theorem andb3_exchange :
  forall b c d, andb (andb b c) d = andb (andb b d) c.
Proof. (* FILL IN HERE *) Admitted.
(** [] *)

(** **** Exercise: 2 stars, standard (andb_true_elim2)

    The following theorem from [Basics] can't be proved with
    [destructpf]. *)

Theorem andb_true_elim2 : forall b c : bool,
  andb b c = true -> c = true.
Proof.
  intros b c. destruct b eqn:Eb.
  - simpl. intros H. rewrite H. reflexivity.
  - simpl. intros H. destruct c eqn:Ec.
    + reflexivity.
    + rewrite H. reflexivity.
Qed.

(** Uncomment the definition of [destructpf'], below, and define your
    own, improved version of [destructpf]. Use it to prove the
    theorem. *)

(*
Ltac destructpf' x := ...
*)

(** Your one-shot proof should need only [intros] and
    [destructpf']. *)

Theorem andb_true_elim2' : forall b c : bool,
    andb b c = true -> c = true.
Proof. (* FILL IN HERE *) Admitted.

(** Double-check that [intros] and your new [destructpf'] still
    suffice to prove this earlier theorem -- i.e., that your improved
    tactic is general enough to still prove it in one shot: *)

Theorem andb3_exchange' :
  forall b c d, andb (andb b c) d = andb (andb b d) c.
Proof. (* FILL IN HERE *) Admitted.
(** [] *)

(* ================================================================= *)
(** ** Ltac Pattern Matching *)

(** Here is another common proof pattern that we have seen in
    many simple proofs by induction: *)

Theorem app_nil_r : forall (X : Type) (lst : list X),
    lst ++ [] = lst.
Proof.
  intros X lst. induction lst as [ | h t IHt].
  - reflexivity.
  - simpl. rewrite IHt. reflexivity.
Qed.

(** At the point we [rewrite], we can't substitute away [t]: it
    is present on both sides of the equality in the inductive
    hypothesis [IHt : t ++ [] = t]. How can we pick out which
    hypothesis to rewrite in an Ltac tactic?

    To solve this and other problems, Ltac contains a pattern-matching
    tactic [match goal].  It allows us to match against the _proof
    state_ rather than against a program. *)

Theorem match_ex1 : True.
Proof.
  match goal with
  | [ |- True ] => apply I
  end.
Qed.

(** The syntax is similar to a [match] in Gallina (Coq's term
    language), but has some new features:

    - The word [goal] here is a keyword, rather than an expression
      being matched. It means to match against the proof state, rather
      than a program term.

    - The square brackets around the pattern can often be omitted, but
      they do make it easier to visually distinguish which part of the
      code is the pattern.

    - The turnstile [|-] separates the hypothesis patterns (if any)
      from the conclusion pattern. It represents the big horizontal
      line shown by your IDE in the proof state: the hypotheses are to
      the left of it, the conclusion is to the right.

    - The hypotheses in the pattern need not completely describe all
      the hypotheses present in the proof state. It is fine for there
      to be additional hypotheses in the proof state that do not match
      any of the patterns. The point is for [match goal] to pick out
      particular hypotheses of interest, rather than fully specify the
      proof state.

    - The right-hand side of a branch is a tactic to run, rather than
      a program term.

    The single branch above therefore specifies to match a goal whose
    conclusion is the term [True] and whose hypotheses may be anything.
    If such a match occurs, it will run [apply I]. *)

(** There may be multiple branches, which are tried in order. *)

Theorem match_ex2 : True /\ True.
Proof.
  match goal with
  | [ |- True ] => apply I
  | [ |- True /\ True ] => split; apply I
  end.
Qed.

(** To see what branches are being tried, it can help to insert calls
    to the identity tactic [idtac]. It optionally accepts an argument
    to print out as debugging information. *)

Theorem match_ex2' : True /\ True.
Proof.
  match goal with
  | [ |- True ] => idtac "branch 1"; apply I
  | [ |- True /\ True ] => idtac "branch 2"; split; apply I
  end.
Qed.

(** Only the second branch was tried. The first one did not match the
    goal. *)

(** The semantics of the tactic [match goal] have a big
    difference with the semantics of the term [match].  With the
    latter, the first matching pattern is chosen, and later branches
    are never considered. In fact, an error is produced if later
    branches are known to be redundant. *)

Fail Definition redundant_match (n : nat) : nat :=
  match n with
  | x => x
  | 0 => 1
  end.

(** But with [match goal], if the tactic for the branch fails,
    pattern matching continues with the next branch, until a branch
    succeeds, or all branches have failed. *)

Theorem match_ex2'' : True /\ True.
Proof.
  match goal with
  | [ |- _ ] => idtac "branch 1"; apply I
  | [ |- True /\ True ] => idtac "branch 2"; split; apply I
  end.
Qed.

(** The first branch was tried but failed, then the second
    branch was tried and succeeded. If all the branches fail, the
    [match goal] fails. *)

Theorem match_ex2''' : True /\ True.
Proof.
  Fail match goal with
  | [ |- _ ] => idtac "branch 1"; apply I
  | [ |- _ ] => idtac "branch 2"; apply I
  end.
Abort.

(** Next, let's try matching against hypotheses. We can bind a
    hypothesis name, as with [H] below, and use that name on the
    right-hand side of the branch. *)

Theorem match_ex3 : forall (P : Prop), P -> P.
Proof.
  intros P HP.
  match goal with
  | [ H : _ |- _ ] => apply H
  end.
Qed.

(** The actual name of the hypothesis is of course [HP], but the
    pattern binds it as [H]. Using [idtac], we can even observe the
    actual name: stepping through the following proof causes "HP" to
    be printed. *)

Theorem match_ex3' : forall (P : Prop), P -> P.
Proof.
  intros P HP.
  match goal with
  | [ H : _ |- _ ] => idtac H; apply H
  end.
Qed.

(** We'll keep using [idtac] for awhile to observe the behavior
    of [match goal], but, note that it isn't necessary for the
    successful proof of any of the following examples.

    If there are multiple hypotheses that match, which one does Ltac
    choose? Here is a big difference with regular [match] against
    terms: Ltac will try all possible matches until one succeeds (or
    all have failed). *)

Theorem match_ex4 : forall (P Q : Prop), P -> Q -> P.
Proof.
  intros P Q HP HQ.
  match goal with
  | [ H : _ |- _ ] => idtac H; apply H
  end.
Qed.

(** That example prints "HQ" followed by "HP". Ltac first
    matched against the most recently introduced hypothesis [HQ] and
    tried applying it. That did not solve the goal. So Ltac
    _backtracks_ and tries the next most-recent matching hypothesis,
    which is [HP]. Applying that does succeed. *)

(** But if there were no successful hypotheses, the entire match
    would fail: *)

Theorem match_ex5 : forall (P Q R : Prop), P -> Q -> R.
Proof.
  intros P Q R HP HQ.
  Fail match goal with
  | [ H : _ |- _ ] => idtac H; apply H
  end.
Abort.

(** So far we haven't been very demanding in how to match
    hypotheses. The _wildcard_ (aka _joker_) pattern we've used
    matches everything. We could be more specific by using
    _metavariables_: *)

Theorem match_ex5 : forall (P Q : Prop), P -> Q -> P.
Proof.
  intros P Q HP HQ.
  match goal with
  | [ H : ?X |- ?X ] => idtac H; apply H
  end.
Qed.

(** Note that this time, the only hypothesis printed by [idtac]
    is [HP]. The [HQ] hypothesis is ruled out, because it does not
    have the form [?X |- ?X].

    The occurrences of [?X] in that pattern are as _metavariables_
    that stand for the same term appearing both as the type of
    hypothesis [H] and as the conclusion of the goal.

    (The syntax of [match goal] requires that [?] to distinguish
    metavariables from other identifiers that might be in
    scope. However, the [?] is used only in the pattern. On the
    right-hand side of the branch, it's actually required to drop the
    [?].) *)

(** Now we have seen yet another difference between [match goal]
    and regular [match] against terms: [match goal] allows a
    metavariable to be used multiple times in a pattern, each time
    standing for the same term.  The regular [match] does not allow
    that: *)

Fail Definition dup_first_two_elts (lst : list nat) :=
  match lst with
  | x :: x :: _ => true
  | _ => false
  end.

(** The technical term for this is _linearity_: regular [match]
    requires pattern variables to be _linear_, meaning that they are
    used only once. Tactic [match goal] permits _non-linear_
    metavariables, meaning that they can be used multiple times in a
    pattern and must bind the same term each time. *)

(** Now that we've learned a bit about [match goal], let's return
    to the proof pattern of some simple inductions: *)

Theorem app_nil_r' : forall (X : Type) (lst : list X),
    lst ++ [] = lst.
Proof.
  intros X lst. induction lst as [ | h t IHt].
  - reflexivity.
  - simpl. rewrite IHt. reflexivity.
Qed.

(** With [match goal], we can automate that proof pattern: *)

Ltac simple_induction t :=
  induction t; simpl;
  try match goal with
      | [H : _ = _ |- _] => rewrite H
      end;
  reflexivity.

Theorem app_nil_r'' : forall (X : Type) (lst : list X),
    lst ++ [] = lst.
Proof.
  intros X lst. simple_induction lst.
Qed.

(** That works great! Here are two other proofs that follow the same
    pattern. *)

Theorem add_assoc'' : forall n m p : nat,
    n + (m + p) = (n + m) + p.
Proof.
  intros n m p. induction n.
  - reflexivity.
  - simpl. rewrite IHn. reflexivity.
Qed.

Theorem add_assoc''' : forall n m p : nat,
    n + (m + p) = (n + m) + p.
Proof.
  intros n m p. simple_induction n.
Qed.

Theorem plus_n_Sm : forall n m : nat,
    S (n + m) = n + (S m).
Proof.
  intros n m. induction n.
  - reflexivity.
  - simpl. rewrite IHn. reflexivity.
Qed.

Theorem plus_n_Sm' : forall n m : nat,
    S (n + m) = n + (S m).
Proof.
  intros n m. simple_induction n.
Qed.

(* ================================================================= *)
(** ** Using [match goal] to Prove Tautologies *)

(** The Ltac source code of [intuition] can be found in the GitHub
    repo for Coq in [theories/Init/Tauto.v]. At heart, it is a big
    loop that runs [match goal] to find propositions it can [apply]
    and [destruct].

    Let's build our own simplified "knock off" of [intuition]. Here's
    a start on implication: *)

Ltac imp_intuition :=
  repeat match goal with
         | [ H : ?P |- ?P ] => apply H
         | [ |- forall _, _ ] => intro
         | [ H1 : ?P -> ?Q, H2 : ?P |- _ ] => apply H1 in H2
         end.

(** That tactic repeatedly matches against the goal until the match
    fails to make progress. At each step, the [match goal] does one of
    three things:

    - Finds that the conclusion is already in the hypotheses, in which
      case the goal is finished.

    - Finds that the conclusion is a quantification, in which case it
      is introduced. Since implication [P -> Q] is itself a
      quantification [forall (_ : P), Q], this case handles introduction of
      implications, too.

    - Finds that two formulas of the form [?P -> ?Q] and [?P] are in
      the hypotheses. This is the first time we've seen an example of
      matching against two hypotheses simultaneously.  Note that the
      metavariable [?P] is once more non-linear: the same formula must
      occur in two different hypotheses.  In this case, the tactic
      uses forward reasoning to change hypothesis [H2] into [?Q].

    Already we can prove many theorems with this tactic: *)

Example imp1 : forall (P : Prop), P -> P.
Proof. imp_intuition. Qed.

Example imp2 : forall (P Q : Prop), P -> (P -> Q) -> Q.
Proof. imp_intuition. Qed.

Example imp3 : forall (P Q R : Prop), (P -> Q -> R) -> (Q -> P -> R).
Proof. imp_intuition. Qed.

(** Suppose we were to add a new logical connective: [nor], the "not
    or" connective. *)

Inductive nor (P Q : Prop) :=
| stroke : ~P -> ~Q -> nor P Q.

(** Classically, [nor P Q] would be equivalent to [~(P \/ Q)].  But
    constructively, only one direction of that is provable. *)

Theorem nor_not_or : forall (P Q : Prop),
    nor P Q -> ~ (P \/ Q).
Proof.
  intros. destruct H. unfold not. intros. destruct H. auto. auto.
Qed.

(** Some other usual theorems about [nor] are still provable,
    though. *)

Theorem nor_comm : forall (P Q : Prop),
    nor P Q <-> nor Q P.
Proof.
  intros P Q. split.
  - intros H. destruct H. apply stroke; assumption.
  - intros H. destruct H. apply stroke; assumption.
Qed.

Theorem nor_not : forall (P : Prop),
    nor P P <-> ~P.
Proof.
  intros P. split.
  - intros H. destruct H. assumption.
  - intros H. apply stroke; assumption.
Qed.

(** **** Exercise: 4 stars, advanced (nor_intuition) *)

(** Create your own tactic [nor_intuition]. It should be able to
    prove the three theorems above -- [nor_not_and], [nor_comm], and
    [nor_not] -- fully automatically. You may not use [intuition] or
    any other automated solvers in your solution.

    Begin by copying the code from [imp_intuition]. You will then need
    to expand it to handle conjunctions, negations, bi-implications,
    and [nor]. *)

(* Ltac nor_intuition := ... *)

(** Each of the three theorems below, and many others involving these
    logical connectives, should be provable with just
    [Proof. nor_intuition. Qed.] *)

Theorem nor_comm' : forall (P Q : Prop),
    nor P Q <-> nor Q P.
Proof. (* FILL IN HERE *) Admitted.

Theorem nor_not' : forall (P : Prop),
    nor P P <-> ~P.
Proof. (* FILL IN HERE *) Admitted.

Theorem nor_not_and' : forall (P Q : Prop),
    nor P Q -> ~ (P /\ Q).
Proof. (* FILL IN HERE *) Admitted.
(* Do not modify the following line: *)
Definition manual_grade_for_nor_intuition : option (nat*string) := None.
(** [] *)

(* ################################################################# *)
(** * Review *)

(** We've learned a lot of new features and tactics in this chapter:

    - [try], [;], [repeat]

    - [assumption], [contradiction], [subst], [constructor]

    - [lia], [congruence], [intuition]

    - [auto], [eauto], [eapply]

    - Ltac functions and [match goal] *)

(* 2023-10-03 16:40 *)