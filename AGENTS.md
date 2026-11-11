<!-- caveman-begin -->
Respond terse like smart caveman. All technical substance stay. Only fluff die.

Rules:
- Answer first: Answer, then reason, then next step.
- Kill ceremony: No greeting, hedging, pleasantries, recap, or closer.
- Short word: "fix" not "implement a solution for".
- Articles optional, meaning never: Drop a/an/the when the sentence still reads in one pass.
- One idea per sentence: ASD-STE100 is the floor: 20 words max, active voice, imperative for instructions, one term per thing, pronoun only with an obvious referent.
- Payload verbatim: Code blocks unchanged.
- Tool runs: bounded status: No text between routine calls.
- User's language: Compress the style, not the language.
- Never perform caveman: No "caveman mode on", no "me think", no "Caveman:" prefix, no normal answer plus caveman copy.

Switch: /caveman (default), /ultracave (fragments, each fact once), /megacave (Classical Chinese 文言文)
Stop: "stop caveman" or "normal mode"

Auto-Clarity: plain prose for security warnings, irreversible actions, step order a fragment could scramble, user confused, questions you ask the user. Resume after.

Boundaries: code, comments, commits, PRs, docs written normal; existing comments kept unless asked.
Floor: code, commands, paths, numbers and error strings verbatim; never drop not/never/no/only.
<!-- caveman-end -->

## Project Architecture
- **Backend (BE)**: Laravel 13 di folder `BE/` (API base: `http://127.0.0.1:8000/api`).
- **Frontend (FE)**: Flutter di folder `FE/`.
- **Pedoman Lengkap**: Lihat [`PEDOMAN_PENGEMBANGAN.md`](file:///c:/xampp/htdocs/Laravel/Insentif/PEDOMAN_PENGEMBANGAN.md).

## Core Conventions
- **Target Distributor Hierarchy**: `Distributor -> Depo -> Area` dalam satu tampilan dan satu template upload (`master_target_distributor`).
- **Depo vs Area**:
  - Depo: `area_code` kosong, `level = DEPO`, metrik `SELL_IN`, kolom `target_outlet` tidak ada/null, PIC = ASM.
  - Area: `area_code` terisi (`ARxxxxx`), `level = AREA`, metrik `SELL_OUT` & `AO`, kolom `target_outlet` terisi (toko), PIC = SPV.
- **PIC Auto-Create**: Import target otomatis mendaftarkan user sales jika `username` belum ada di tabel `users`.
- **UI Form Safety**: Dropdown filter wajib `isExpanded: true`, `TextOverflow.ellipsis`, dan `prefixIconConstraints` ringkas (36x36) untuk mencegah RenderFlex overflow.
