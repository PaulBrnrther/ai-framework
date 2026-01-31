# AI Framework

## Purpose

This repository maintains the usage of AI agents (currently: Claude Code) and provides a framework for iterating their environment after given time intervals (e.g., every end-of-day).

## Main Functionalities

### (a) Framework Setup

The framework defines the general setup on the computer, addressing questions like:

- Where do I want to create new helper-tools?
- How do I manage the environment?
- How do I handle multiple environments (if needed)?
- How do I create a new environment?

This is the **product** that this repository ships.

### (b) Self-Improvement Process

A system for continuously improving the framework itself, supporting improvements ranging from small to groundbreaking:

- **Small notes**: Capture ideas for future improvements
- **Reusable tools**: Extract tools that might be useful in other circumstances
- **Environments**: Create dedicated setups for specific tasks

**Workflow:**
- During regular work: Improvements can be issued manually when something reusable is identified ("hey, this might be useful elsewhere, let's make it reusable")
- Manual improvements during development should not be relied upon too heavily here, as they can become a side-track
- Thus: At dedicated intervals: Actively review, clean up, and develop ideas that originated from conversations since the last review session

The time interval (e.g., end-of-day) serves as the point to both:
- Review what happened
- Extract learnings
- Run the self-improvement process (modifying/adding tools, environments, etc.)

(In the future, this might be largely automated, resulting in a PR to review the next morning)

## Terminology

These terms are used consistently throughout, though their precise definitions will evolve:

- **Environment**: Umbrella term for all things that can be set up before starting a conversation with an agent:
  - System prompts
  - **Tool**:
    - Documentation (e.g. specific on-demand Prompts)
    - Commands (deterministic helpers (e.g. MCPs but also just terminal commands))
    - Agents (non-deterministic helpers)
  - Permissions (to perform specific actions without asking; access to specific repos)
