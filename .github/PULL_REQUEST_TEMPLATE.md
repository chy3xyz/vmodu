## Summary

-

## Test plan

- [ ] `v run main.v` or `v -o /tmp/vmodu_main main.v` starts
- [ ] `curl http://127.0.0.1:8080/health` → 200 (if HTTP / entry changed)
- [ ] Related modules: `v test <path>` (see CONTRIBUTING recommended list)
- [ ] Docs / README module table updated (if user-facing behavior changed)

## Notes

Call out experimental modules (WASM / partial LLM / chain adapters) in the description.

<!-- 中文也可写在 Summary / Notes 中；仓库文档默认英文。 -->
