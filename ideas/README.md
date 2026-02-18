# Idea Management

## Workflow

```
                ┌─────────────┐
                │  Developer   │
                │  has idea    │
                └──────┬──────┘
                       │
                       ▼
              ┌────────────────┐
              │  idea "..."    │
              │  (capture it)  │
              └───────┬────────┘
                      │
                      ▼
            ┌──────────────────┐
            │  ideas/<name>.md │
            │  (inbox)         │
            └────────┬─────────┘
                     │
                     │  review session
                     ▼
              ┌─────────────┐
              │  Qualify it  │
              └──┬───────┬──┘
                 │       │
          worth it    not now      not worth it
                 │       │              │
                 ▼       ▼              ▼
     ┌───────────────┐ ┌────────────┐ ┌─────────┐
     │ ideas/backlog/ │ │ ideas/later/│ │ discard │
     └───────┬───────┘ └────────────┘ └─────────┘
             │
             │  spec out (one or more
             │  ideas → one package)
             ▼
     ┌────────────────────┐
     │ backlog/<name>.md  │
     │ (working package)  │
     └────────┬───────────┘
              │
              │  pick up
              ▼
     ┌─────────────────────────┐
     │ in-progress/<name>.md   │
     │ + spec.md (optional)    │
     └────────┬────────────────┘
              │
              │  done
              ▼
        ┌───────────┐
        │  archive   │
        └───────────┘
```

## Folder Structure

- `ideas/*.md` — **Inbox**: Raw, unqualified ideas captured via the `idea` command. This is where new ideas land.
- `ideas/backlog/` — **Backlog**: Qualified ideas and specced-out working packages (`.md` files) ready to be picked up.
- `ideas/in-progress/` — **In Progress**: Working packages currently being implemented. May include a `spec.md` with detailed design.
- `ideas/later/` — **Later**: Interesting ideas that aren't urgent. Revisit periodically.
- `ideas/meta-add-ideas-framework/` — Documentation for the idea capture tooling itself.

## Stages

### 1. Capture (Inbox)

During development, capture ideas as they come up:

```bash
idea "your free-text thought"
```

This creates a markdown file in `ideas/` with a timestamp and structured description. Don't overthink it — just capture and move on.

### 2. Qualify (Review Session)

At dedicated intervals (e.g., end-of-day), review inbox ideas:

- **Read** each idea in `ideas/*.md`
- **Decide**: Is this worth pursuing?
  - **Yes, urgent** → Move to `ideas/backlog/`
  - **Yes, but not now** → Move to `ideas/later/`
  - **No** → Delete the file

### 3. Spec Out (Working Package)

A **working package** is a specced-out unit of work originating from one or more ideas. It lives as a single `.md` file in `ideas/backlog/`.

**Creating a working package:**

1. Identify one or more related ideas (from backlog or later)
2. Create `ideas/backlog/<name>.md` with the following structure:
   ```markdown
   # <Working Package Title>

   ## Origin Ideas
   - `<idea_filename>.md`
   - `<another_idea_filename>.md`

   ## Goal
   What this working package achieves.

   ## Spec
   Concrete description of what needs to be built/changed.

   ## Open Questions
   Anything unresolved (optional).
   ```
3. Delete the original idea files from the inbox/backlog — the working package replaces them

**Key principles:**

- The **Origin Ideas** section lists the original idea filenames. This preserves traceability — each idea file's timestamp and "issued from" metadata lets you find the Claude conversation that spawned it.
- The spec is a **reformulation**, not a copy-paste. Synthesize the ideas into a coherent, actionable description.
- A working package can combine ideas from both `backlog/` and `later/` if they turn out to be related.
- Unqualified ideas that were moved to backlog without being specced can coexist alongside working packages in `backlog/` — speccing is not mandatory for small items.

### 4. Execute

Pick a working package from `ideas/backlog/` and move it to `ideas/in-progress/`. Optionally create a `spec.md` alongside it with detailed design, UX simulation, or implementation notes. When done, archive or delete the files from `in-progress/`.
