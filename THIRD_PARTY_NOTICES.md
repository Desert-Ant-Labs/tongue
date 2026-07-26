# Third-party notices — tongue

tongue is trained from scratch and does not derive from any third-party model.
The training and evaluation corpora below are licensed by their respective
projects, and those licenses apply to that data. Nothing in the Desert Ant Labs
Source-Available License overrides them.

Every source used for training is CC0, CC BY, or a permissive software license.
Share-alike and non-commercial sources are excluded by policy, and the corpus
build enforces the exclusion and records a provenance manifest of every file
kept and dropped.

## Training data

### Tatoeba — sentence and link exports
- **Source:** [tatoeba.org](https://tatoeba.org) — `downloads.tatoeba.org/exports/`
- **License:** CC BY 2.0 FR
- **Attribution:** © Tatoeba contributors, licensed under CC BY 2.0 FR
- **Use in tongue:** the primary corpus. Sentences are windowed into 1–5 and
  8-word spans, and their distinct tokens supply single-word training rows. The
  translation-link graph is used to split train/validation by translation family
  so a sentence and its translations cannot straddle the split.

### Common Voice — sentence collections
- **Source:** [common-voice/common-voice](https://github.com/common-voice/common-voice) (`server/data`)
- **License:** CC0 1.0
- **Use in tongue:** additional sentence-register text, strongest for languages
  where Tatoeba is thin (Catalan, Basque, Galician, Welsh, Swahili, Belarusian).
- **Exclusions:** files derived from Wikipedia or Europarl are **not** used, as
  their upstream sources are share-alike. The fetcher drops any file matching
  `*wiki*` or `*europarl*` and writes the resulting keep/drop manifest.

### Wikidata Lexemes
- **Source:** [wikidata.org](https://www.wikidata.org) lexeme dumps
- **License:** CC0 1.0
- **Use in tongue:** dictionary-register vocabulary rows (single words).

### Hunspell dictionaries
- **Source:** [wooorm/dictionaries](https://github.com/wooorm/dictionaries) — English, Dutch, Lithuanian, Russian, Turkish, Persian
- **License:** per dictionary (MIT / BSD / Apache-2.0 and similar permissive terms; see each dictionary's own license file)
- **Use in tongue:** additional clean single-word vocabulary for those six languages.

### Universal Dependencies treebanks
- **Source:** [universaldependencies.org](https://universaldependencies.org)
- **License:** CC BY 4.0 (attribution required), verified per treebank
- **Treebanks used:** UD_Spanish-AnCora, UD_Catalan-AnCora, UD_Finnish-FTB,
  UD_Italian-MarkIT, UD_Portuguese-Porttinari
- **Use in tongue:** written-register sentences (news, reviews), taken from the
  `# text =` lines. Share-alike and non-commercial UD treebanks are excluded.

## Evaluation only — never used for training

- **FLORES-200** — NLLB Team et al. — CC BY-SA 4.0 — held out; used for the
  neutral truncation benchmark.
- **WiLI-2018** — ODC-BY 1.0 — held out; tail-language coverage check.
- **eld benchmark** — [nitotm/efficient-language-detector](https://github.com/nitotm/efficient-language-detector) — Apache-2.0 — held out; independent generalization check.

These sets are used to measure the model and are never part of the training
corpus. Leipzig / Wortschatz corpora are excluded from training in every form
(news, web, wiki, frequency lists, and mirrors), because another detector's
published test set is drawn from that collection and training on it would make
comparisons meaningless.

## Comparison baselines

Numbers reported alongside tongue were produced by running these systems on the
identical rows and language subsets. They are not redistributed here.

- **lingua** ([pemistahl/lingua-py](https://github.com/pemistahl/lingua-py)) — Apache-2.0
- **eld** ([nitotm/efficient-language-detector](https://github.com/nitotm/efficient-language-detector)) — Apache-2.0
- **HeLI-OTS** — [University of Helsinki](https://zenodo.org/record/841984) — used as published
- **Apple `NLLanguageRecognizer`** — the operating-system detector, measured through a Swift harness
