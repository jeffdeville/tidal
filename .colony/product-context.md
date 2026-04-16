---
project_name: "Tidal"
slug: "tidal"
description: "Elixir MCP server library with per-session GenServer isolation"
tech_stack: ["elixir", "otp", "plug", "bandit"]
maturity: greenfield
---

# Tidal — Product Context

## What It Is

Tidal is an Elixir library for building MCP (Model Context Protocol) servers. It implements the MCP 2025-11-25 spec using Streamable HTTP transport, giving each connected client its own supervised GenServer session — inspired by Phoenix LiveView's per-connection process model.

## Who It's For

1. **Colony** (primary) — Tidal powers Colony's agent-to-tool communication layer
2. **Elixir community** — developers building MCP-compatible tool servers

## Key Differentiator

Existing Elixir MCP libraries bottleneck all clients through a single process. Tidal gives each client isolated state, supervision, and lifecycle management via OTP primitives.

## Current State

Core functionality is working:
- Session lifecycle (create → initialize → ready → shutdown)
- Tool dispatch with `defop` macro and middleware pipeline
- Resource serving with templates and subscriptions
- Auto-reconnect for expired sessions via ETS cache
- Streamable HTTP transport via Plug

## What's Left (MCP Spec Coverage)

Remaining spec features to implement: prompts, logging, sampling, roots, tasks, pagination, cancellation, progress tracking, and extensions.
