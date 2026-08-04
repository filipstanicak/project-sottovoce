# Architecture guards

**Do not delete these tests. Do not weaken them to make a change pass.**

They protect the *architecture* rather than behaviour, they run as source scans
rather than by executing code, and every one exists because the thing it
prevents is **invisible in ordinary review**.

## If one fails

The change is wrong, or an ADR is needed. Never the test.

That is a stop-and-ask condition in
[`../../docs/30_bible/AGENT_PLAYBOOK.md`](../../docs/30_bible/AGENT_PLAYBOOK.md) §3.

## What they catch

| Test | Prevents | Why review misses it |
|---|---|---|
| `test_layer_dependencies` | A system referencing presentation | The code works; only the headless server build breaks, later |
| `test_core_is_pure` | Core acquiring a Node or autoload | Nothing fails until Core stops being unit-testable |
| `test_eventbus_is_stateless` | The bus becoming a global variable | It looks like a convenience at the time |
| `test_eventbus_signals_documented` | A signal in code but not the catalogue, **or the reverse** | Both read fine alone |
| `test_signal_naming` | `on_x` / `do_x` / `x_signal` | An imperative name invites a listener to do the emitter's work |
| `test_prey_warning_signal_arity` | A parameter on the prey warning | One token, compiles, and deletes the best moment in the game |
| `test_no_gameplay_literals` | A hardcoded constant two paths disagree about | Both values look reasonable in isolation |
| `test_pawn_determinism_grep` | Nondeterminism in predicted code | Surfaces only under load, intermittently |
| `test_no_client_authority` | An RPC letting a client assert an outcome | The handler reads like ordinary code |
| `test_tuning_docs_sync` | Documentation drifting from code | Both files are individually plausible |
| `test_autoload_inventory` | A ninth autoload | Each addition is individually defensible |
| `test_game_state_single_writer` | A second writer to the shared mirror | The assignment reads as ordinary code and works |
| `test_ids_match_glossary` | An ID in code but not the docs, **or the reverse** | Each file reads fine alone; only the comparison shows the gap |
| `test_id_grammar` | A malformed ID | `MAT-GREY-FLOOR` and `MAT-STONE` both look like material IDs |
| `test_ids_are_stringname` | `"ID"` where `&"ID"` was meant | One character; behaviour is identical, allocation is not |

The last one is the pattern: these failures are all *individually defensible*
and *collectively fatal*.
