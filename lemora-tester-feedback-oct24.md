# Lemora — Tester Feedback (Oct 24, 2026)

## Feedback compilé de 2 testeurs + Jules

### 1. Meal Planning — Calendrier de repas de la semaine
- Pouvoir planifier tous les repas de la semaine (déjeuner, dîner, souper)
- Vue claire: "Lundi matin → tel repas, Mardi soir → tel repas"
- Structuré par jour et par moment de la journée
- Générer une liste d'épicerie directement à partir du plan de la semaine

### 2. Garde-manger (Pantry)
- Section pour noter les aliments qu'on a déjà chez soi
- La liste d'épicerie doit soustraire ce qu'on a déjà
- Ça structure aussi les propositions de recettes

### 3. Barre de recherche de recettes
- En plus du swipe Discover, avoir une barre de recherche pour trouver des recettes spécifiques

### 4. Épices dans les recettes
- Les recettes manquent d'épices et d'assaisonnements → goût fade
- Modifier la génération de recettes pour toujours inclure les épices appropriées

### 5. Variété même avec budget serré
- Testeur à 150$/semaine → ne recevait que patates et poisson
- Diversifier les propositions même quand le budget est tight

### 6. Like ≠ Save
- Swipe droite = **like seulement**. Ça n'ajoute pas automatiquement aux recettes Saved.
- Onglet **Saved**: table principale = recettes volontairement saved, triables pour la semaine.
- Les likes sont une **petite rangée**, pas la table d'arrivée.
- Depuis un like, on peut **Save** pour le garder / le mettre dans le plan de la semaine.

### 7. Bouton "Je l'ai cuisiné" → simple
- Pas de nouvelle page / sheet CookedView.
- Toggle sur place: "I cooked this" → toast "Cooked · you saved $X".
- Repas passés dans le calendrier → à auto-marquer comme mangés (encore à faire).

### 8. Savings plus en avant dans le Profil
- Le montant sauvé par semaine doit être BEAUCOUP plus gros/visible
- "Combien tu saves par semaine" en gros

---

## Ajustements visuels (Design Reference v10 + pièce jointe)

### Barre du bas (Tab Bar)
- Ordre: Deals · Saved · **Discover** (centre) · Ask · Profile
- Icônes inchangées pour Deals (`tag`), Ask (bulles), Profile (`person`)
- **Saved** (plus Liked) avec signet `bookmark.fill`
- **Discover**: gros cercle jaune `#EFD35A`, carte arrondie comme le mock (pas de loupe), label Discover, bouton relevé
- À l'ouverture de l'app → **Discover** (feature principale)

### Écran 1 — Week Plan (Saved tab → Week plan)
- Toggle "Saved / Week plan" en haut du Saved tab
- Calendrier semaine, Mark eaten, grocery depuis le plan

### Langue in-app
- Choisir FR (ou ES) → tout le texte UI dans cette langue
- Bug fixé: GET STARTED / Already have an account? / Log in / cartes d'options passent par `lemoraLocalized`

---

## Notifications à implémenter

### Push Notifications
- **Rappel meal plan du matin** — "Voici tes repas pour aujourd'hui" (ex: 8h)
- **Rappel épicerie** — "Ta liste d'épicerie est prête" quand le plan de la semaine est complété
- **Nouveaux deals** — "3 nouveaux deals dans tes épiceries"
- **Rappel "Mark as eaten"** — "As-tu mangé ton [recette]?" en soirée
- **Milestone savings** — "$50 saved this month!"
- **Nouvelles recettes** — "5 nouvelles recettes qui matchent ton budget" (hebdomadaire)

---

## Statut d'implémentation

### Complété (ce build)
- Like ≠ Save: swipe droite like seulement; Saved est volontaire
- Petite rangée Likes dans Saved; table principale = saved
- Toggle Saved / Week plan
- "I cooked this" sur place + toast économies (plus de sheet)
- Tab bar: Saved + Discover jaune carte (mock)
- Ouverture sur Discover
- Landing FR: COMMENCER / Tu as déjà un compte? / Se connecter
- `/testflight` enregistré: modifier → push GitHub main → build TestFlight

### En cours / à faire
- Barre de recherche de recettes
- Section épices dans le detail
- Variété budgets serrés
- Auto-mark repas passés
- Notifications push
- Grocery list liée au pantry ("already at home")
- "Cook with what you have"
- Liked "Top 4" par repas
- Profile hero savings v10
