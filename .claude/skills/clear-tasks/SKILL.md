---
name: clear-tasks
description: Clear all tasks from the Colony database
disable-model-invocation: true
---

Clear all tasks from the Colony database by running:

```bash
mix run -e "Colony.Repo.delete_all(Colony.Tasks.Task)"
```

After clearing, verify with:

```bash
mix run -e "IO.puts(\"Tasks remaining: #{length(Colony.Tasks.list_tasks())}\")"
```

Report the result to the user.
