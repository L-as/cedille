module datatype-functions where
open import lib
open import ctxt
open import syntax-util
open import general-util
open import cedille-types
open import subst
open import rename
open import is-free

data indx : Set where
  Index : var → tk → indx
indices = 𝕃 indx

data datatype : Set where
  Data : var → params → indices → ctrs → datatype

{-# TERMINATING #-}
decompose-arrows : ctxt → type → params × type
decompose-arrows Γ (Abs pi me pi' x atk T) =
  let x' = fresh-var x (ctxt-binds-var Γ) empty-renamectxt in
  case decompose-arrows (ctxt-var-decl x' Γ) (rename-var Γ x x' T) of λ where
    (ps , T') → Decl posinfo-gen posinfo-gen me x' atk posinfo-gen :: ps , T'
decompose-arrows Γ (TpArrow T me T') =
  let x = fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt in
  case decompose-arrows (ctxt-var-decl x Γ) T' of λ where
    (ps , T'') → Decl posinfo-gen posinfo-gen me x (Tkt T) posinfo-gen :: ps , T''
decompose-arrows Γ (TpParens pi T pi') = decompose-arrows Γ T
decompose-arrows Γ T = [] , T

decompose-ctr-type : ctxt → type → type × params × 𝕃 tty
decompose-ctr-type Γ T with decompose-arrows Γ T
...| ps , Tᵣ with decompose-tpapps Tᵣ
...| Tₕ , as = Tₕ , ps , as

{-# TERMINATING #-}
kind-to-indices : ctxt → kind → indices
kind-to-indices Γ (KndArrow k k') =
  let x' = fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt in
  Index x' (Tkk k) :: kind-to-indices (ctxt-var-decl x' Γ) k'
kind-to-indices Γ (KndParens pi k pi') = kind-to-indices Γ k
kind-to-indices Γ (KndPi pi pi' x atk k) =
  let x' = fresh-var x (ctxt-binds-var Γ) empty-renamectxt in
  Index x' atk :: kind-to-indices (ctxt-var-decl x' Γ) k
kind-to-indices Γ (KndTpArrow T k) =
  let x' = fresh-var "x" (ctxt-binds-var Γ) empty-renamectxt in
  Index x' (Tkt T) :: kind-to-indices (ctxt-var-decl x' Γ) k
kind-to-indices Γ (KndVar pi x as) with ctxt-lookup-kind-var-def Γ x
...| nothing = []
...| just (ps , k) = kind-to-indices Γ $ fst $ subst-params-args Γ ps as k
kind-to-indices Γ (Star pi) = []

defDatatype-to-datatype : ctxt → defDatatype → datatype
defDatatype-to-datatype Γ (Datatype _ _ x ps k cs) =
  Data x ps (kind-to-indices Γ k) cs

tk-erased : tk → maybeErased → maybeErased
tk-erased (Tkk _) me = Erased
tk-erased (Tkt _) me = me

params-set-erased : maybeErased → params → params
params-set-erased me = map λ where
  (Decl pi pi' me' x atk pi'') → Decl pi pi' me x atk pi''

args-set-erased : maybeErased → args → args
args-set-erased me = map λ where
  (TermArg me' t) → TermArg me t
  (TypeArg T) → TypeArg T

indices-to-kind : indices → kind → kind
indices-to-kind = flip $ foldr λ {(Index x atk) → KndPi posinfo-gen posinfo-gen x atk}

params-to-kind : params → kind → kind
params-to-kind = flip $ foldr λ {(Decl pi pi' me x atk pi'') → KndPi pi pi' x atk}

indices-to-tplams : indices → (body : type) → type
indices-to-tplams = flip $ foldr λ where
  (Index x atk) → TpLambda posinfo-gen posinfo-gen x atk

params-to-tplams : params → (body : type) → type
params-to-tplams = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → TpLambda pi pi' x atk

indices-to-alls : indices → (body : type) → type
indices-to-alls = flip $ foldr λ where
  (Index x atk) → Abs posinfo-gen Erased posinfo-gen x atk

params-to-alls : params → (body : type) → type
params-to-alls = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → Abs pi (tk-erased atk me) pi' x atk

indices-to-lams : indices → (body : term) → term
indices-to-lams = flip $ foldr λ where
  (Index x atk) → Lam posinfo-gen Erased posinfo-gen x (SomeClass atk)

indices-to-lams' : indices → (body : term) → term
indices-to-lams' = flip $ foldr λ where
  (Index x atk) → Lam posinfo-gen Erased posinfo-gen x NoClass

params-to-lams : params → (body : term) → term
params-to-lams = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → Lam pi (tk-erased atk me) pi' x (SomeClass atk)

params-to-lams' : params → (body : term) → term
params-to-lams' = flip $ foldr λ where
  (Decl pi pi' me x atk pi'') → Lam pi (tk-erased atk me) pi' x NoClass

indices-to-apps : indices → (body : term) → term
indices-to-apps = flip $ foldl λ where
  (Index x (Tkt T)) t → App t Erased (mvar x)
  (Index x (Tkk k)) t → AppTp t (mtpvar x)

params-to-apps : params → (body : term) → term
params-to-apps = flip $ foldl λ where
  (Decl pi pi' me x (Tkt T) pi'') t → App t me (mvar x)
  (Decl pi pi' me x (Tkk k) pi'') t → AppTp t (mtpvar x)

indices-to-tpapps : indices → (body : type) → type
indices-to-tpapps = flip $ foldl λ where
  (Index x (Tkt T)) T' → TpAppt T' (mvar x)
  (Index x (Tkk k)) T  → TpApp  T  (mtpvar x)

params-to-tpapps : params → (body : type) → type
params-to-tpapps = flip $ foldl λ where
  (Decl pi pi' me x (Tkt T) pi'') T' → TpAppt T' (mvar x)
  (Decl pi pi' me x (Tkk k) pi'') T  → TpApp  T  (mtpvar x)

ctrs-to-lams' : ctrs → (body : term) → term
ctrs-to-lams' = flip $ foldr λ where
  (Ctr _ x T) → Lam posinfo-gen NotErased posinfo-gen x NoClass

ctrs-to-lams : ctxt → var → params → ctrs → (body : term) → term
ctrs-to-lams Γ x ps cs t = foldr
  (λ {(Ctr _ y T) f Γ → Lam posinfo-gen NotErased posinfo-gen y
    (SomeClass $ Tkt $ subst Γ (params-to-tpapps ps $ mtpvar y) y T)
    $ f $ ctxt-var-decl y Γ})
  (λ Γ → t) cs Γ

add-indices-to-ctxt : indices → ctxt → ctxt
add-indices-to-ctxt = flip $ foldr λ {(Index x atk) → ctxt-var-decl x}

add-params-to-ctxt : params → ctxt → ctxt
add-params-to-ctxt = flip $ foldr λ {(Decl _ _ _ x'' _ _) → ctxt-var-decl x''}

add-caseArgs-to-ctxt : caseArgs → ctxt → ctxt
add-caseArgs-to-ctxt = flip $ foldr λ {(CaseTermArg _ _ x) → ctxt-var-decl x; (CaseTypeArg _ x) → ctxt-var-decl x}

add-ctrs-to-ctxt : ctrs → ctxt → ctxt
add-ctrs-to-ctxt = flip $ foldr λ {(Ctr _ x T) → ctxt-var-decl x}

positivity : Set
positivity = 𝔹 × 𝔹 -- occurs positively × occurs negatively

pattern occurs-nil = ff , ff
pattern occurs-pos = tt , ff
pattern occurs-neg = ff , tt
pattern occurs-all = tt , tt

positivity-inc : positivity → positivity
positivity-dec : positivity → positivity
positivity-neg : positivity → positivity
positivity-add : positivity → positivity → positivity

positivity-inc = map-fst λ _ → tt
positivity-dec = map-snd λ _ → tt
positivity-neg = uncurry $ flip _,_
positivity-add (+ₘ , -ₘ) (+ₙ , -ₙ) = (+ₘ || +ₙ) , (-ₘ || -ₙ)



-- just tt = negative occurrence; just ff = not in the return type; nothing = okay
{-# TERMINATING #-}
ctr-positive : ctxt → var → type → maybe 𝔹
ctr-positive Γ x T = arrs+ Γ Tₕ where
  
  open import conversion

  not-free : ∀ {ed} → ⟦ ed ⟧ → maybe 𝔹
  not-free = maybe-map (λ _ → tt) ∘' maybe-if ∘' ~_ ∘' is-free-in check-erased x

  if-free : ∀ {ed} → ⟦ ed ⟧ → positivity
  if-free t with is-free-in check-erased x t
  ...| f = f , f

  hnf' : ctxt → type → type
  hnf' Γ T = hnf Γ unfold-all T tt
  
  Tₕ = hnf' Γ T

  mtt = maybe-else tt id
  mff = maybe-else ff id

  posₒ = fst
  negₒ = snd
  
  occurs : positivity → maybe 𝔹
  occurs p = maybe-if (negₒ p) ≫maybe just tt

  arrs+ : ctxt → type → maybe 𝔹
  type+ : ctxt → type → positivity
  kind+ : ctxt → kind → positivity
  tk+ : ctxt → tk → positivity

  arrs+ Γ (Abs _ _ _ x' atk T) =
    let Γ' = ctxt-var-decl x' Γ in
    occurs (tk+ Γ atk) maybe-or arrs+ Γ' (hnf' Γ' T)
--    mtt (tk+ Γ atk) && arrs+ Γ' (hnf' Γ' T)
  arrs+ Γ (TpApp T T') = arrs+ Γ T maybe-or not-free T'
  arrs+ Γ (TpAppt T t) = arrs+ Γ T maybe-or not-free t
  arrs+ Γ (TpArrow T _ T') = occurs (type+ Γ (hnf' Γ T)) maybe-or arrs+ Γ (hnf' Γ T')
  arrs+ Γ (TpLambda _ _ x' atk T) =
    let Γ' = ctxt-var-decl x' Γ in
    occurs (tk+ Γ atk) maybe-or arrs+ Γ' (hnf' Γ' T)
  arrs+ Γ (TpVar _ x') = maybe-not (maybe-if (x =string x')) ≫maybe just ff
  arrs+ Γ T = just ff
  
  type+ Γ (Abs _ _ _ x' atk T) =
    let Γ' = ctxt-var-decl x' Γ; atk+? = tk+ Γ atk in
    positivity-add (positivity-neg $ tk+ Γ atk) (type+ Γ' $ hnf' Γ' T)
--    maybe-else' (type+ Γ' (hnf' Γ' T)) (maybe-map ~_ atk+?) λ T+? → just $ T+? && ~ mff (tk+ Γ atk)
  type+ Γ (Iota _ _ x' T T') = if-free (Iota pi-gen pi-gen x' T T')
    -- (maybe-not $ maybe-if $ not-free $ Iota posinfo-gen posinfo-gen x' T T') ≫maybe just ff
    {-let Γ' = ctxt-var-decl x' Γ in
    type+ Γ (hnf' Γ T) && type+ Γ' (hnf' Γ' T')-}
  type+ Γ (Lft _ _ x' t lT) = occurs-all
  type+ Γ (NoSpans T _) = type+ Γ T
  type+ Γ (TpLet _ (DefTerm _ x' T? t) T) = type+ Γ (hnf' Γ (subst Γ t x' T))
  type+ Γ (TpLet _ (DefType _ x' k T) T') = type+ Γ (hnf' Γ (subst Γ T x' T'))
  type+ Γ (TpApp T T') = positivity-add (type+ Γ T) (if-free T') -- maybe-map (_&& not-free T') (type+ Γ T)
  type+ Γ (TpAppt T t) = positivity-add (type+ Γ T) (if-free t) -- maybe-map (_&& not-free t) (type+ Γ T)
  type+ Γ (TpArrow T _ T') = positivity-add (positivity-neg $ type+ Γ T) (type+ Γ $ hnf' Γ T')
    -- maybe-else' (type+ Γ (hnf' Γ T')) (maybe-map ~_ (type+ Γ (hnf' Γ T))) λ T'+? → just $ T'+? && ~ mff (type+ Γ (hnf' Γ T))
  type+ Γ (TpEq _ tₗ tᵣ _) = occurs-nil
  type+ Γ (TpHole _) = occurs-nil
  type+ Γ (TpLambda _ _ x' atk T)=
    let Γ' = ctxt-var-decl x' Γ in
    positivity-add (positivity-neg $ tk+ Γ atk) (type+ Γ' (hnf' Γ' T))
  type+ Γ (TpParens _ T _) = type+ Γ T
  type+ Γ (TpVar _ x') = x =string x' , ff
  
  kind+ Γ (KndArrow k k') = positivity-add (positivity-neg $ kind+ Γ k) (kind+ Γ k')
    --maybe-else' (kind+ Γ k') (maybe-map ~_ (kind+ Γ k)) λ k'+? → just $ k'+? && mff (kind+ Γ k)
  kind+ Γ (KndParens _ k _) = kind+ Γ k
  kind+ Γ (KndPi _ _ x' atk k) =
    let Γ' = ctxt-var-decl x' Γ in
    positivity-add (positivity-neg $ tk+ Γ atk) (kind+ Γ' k)
    --maybe-else' (kind+ Γ' k) (maybe-map ~_ tk+?) λ k+? → just $ k+? && mff tk+?
--    kind+ (ctxt-var-decl x' Γ) k && ~ tk+ Γ atk
  kind+ Γ (KndTpArrow T k) = positivity-add (positivity-neg $ type+ Γ T) (kind+ Γ k)
    --maybe-else' (kind+ Γ k) (maybe-map ~_ (type+ Γ T)) λ k+? → just $ k+? && mff (type+ Γ T)
  kind+ Γ (KndVar _ κ as) =
    maybe-else' (ctxt-lookup-kind-var-def Γ κ) occurs-nil $ uncurry λ ps k → kind+ Γ (fst (subst-params-args Γ ps as k))
  kind+ Γ (Star _) = occurs-nil

  tk+ Γ (Tkt T) = type+ Γ (hnf' Γ T)
  tk+ Γ (Tkk k) = kind+ Γ k

