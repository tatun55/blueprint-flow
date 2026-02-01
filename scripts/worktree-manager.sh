#!/bin/bash
# Worktree Manager - Git worktree operations for parallel spec execution
# Usage: ./scripts/worktree-manager.sh <command> [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# プロジェクトルートを検出（.blueprint-flowの親ディレクトリ）
if [[ -d "$PROJECT_ROOT/../.git" ]]; then
    MAIN_PROJECT="$(dirname "$PROJECT_ROOT")"
else
    MAIN_PROJECT="$PROJECT_ROOT"
fi

WORKTREE_DIR="$MAIN_PROJECT/.worktrees"
DB_CLI="$PROJECT_ROOT/scripts/blueprint-db-cli.sh"

show_help() {
    cat << 'EOF'
Worktree Manager Commands:

  create <spec_id>           Create worktree for spec
  cleanup <spec_id>          Remove worktree (keeps branch)
  merge <spec_id>            Merge branch to main and cleanup
  abort <spec_id>            Discard worktree and branch
  list                       List all worktrees
  status <spec_id>           Check worktree status
  path <spec_id>             Get worktree path

Workflow:
  1. create  - Start working on spec (creates branch + worktree)
  2. (work in worktree, commit, push, create PR)
  3. merge   - After PR approval, merge to main
  OR
  3. abort   - If rejected, discard all changes

EOF
}

get_branch_name() {
    local spec_id="$1"
    echo "task/spec-$spec_id"
}

get_worktree_path() {
    local spec_id="$1"
    echo "$WORKTREE_DIR/spec-$spec_id"
}

create_worktree() {
    local spec_id="$1"
    local branch_name=$(get_branch_name "$spec_id")
    local worktree_path=$(get_worktree_path "$spec_id")

    # ディレクトリ作成
    mkdir -p "$WORKTREE_DIR"

    cd "$MAIN_PROJECT"

    # 既存チェック
    if [[ -d "$worktree_path" ]]; then
        echo "{\"success\": false, \"error\": \"Worktree already exists\", \"path\": \"$worktree_path\"}"
        return 1
    fi

    # ブランチ作成（存在しない場合）
    if ! git show-ref --verify --quiet "refs/heads/$branch_name"; then
        git branch "$branch_name" HEAD
    fi

    # worktree作成
    git worktree add "$worktree_path" "$branch_name"

    # DBにブランチ名を記録
    "$DB_CLI" sql "UPDATE specs SET branch = '$branch_name' WHERE id = $spec_id;"

    echo "{\"success\": true, \"path\": \"$worktree_path\", \"branch\": \"$branch_name\"}"
}

cleanup_worktree() {
    local spec_id="$1"
    local worktree_path=$(get_worktree_path "$spec_id")

    cd "$MAIN_PROJECT"

    if [[ -d "$worktree_path" ]]; then
        git worktree remove "$worktree_path" --force 2>/dev/null || true
    fi

    echo "{\"success\": true}"
}

merge_worktree() {
    local spec_id="$1"
    local branch_name=$(get_branch_name "$spec_id")
    local worktree_path=$(get_worktree_path "$spec_id")

    cd "$MAIN_PROJECT"

    # mainに切り替え
    git checkout main

    # マージ（fast-forward不可）
    if git merge "$branch_name" --no-ff -m "Merge spec-$spec_id implementation

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"; then
        # worktree削除
        if [[ -d "$worktree_path" ]]; then
            git worktree remove "$worktree_path" --force 2>/dev/null || true
        fi

        # ブランチ削除
        git branch -d "$branch_name" 2>/dev/null || true

        # DB更新
        "$DB_CLI" sql "UPDATE specs SET branch = NULL WHERE id = $spec_id;"

        echo "{\"success\": true, \"merged\": true}"
    else
        echo "{\"success\": false, \"error\": \"Merge conflict\", \"branch\": \"$branch_name\"}"
        return 1
    fi
}

abort_worktree() {
    local spec_id="$1"
    local branch_name=$(get_branch_name "$spec_id")
    local worktree_path=$(get_worktree_path "$spec_id")

    cd "$MAIN_PROJECT"

    # worktree削除
    if [[ -d "$worktree_path" ]]; then
        git worktree remove "$worktree_path" --force 2>/dev/null || true
    fi

    # ブランチ強制削除
    git branch -D "$branch_name" 2>/dev/null || true

    # DB更新
    "$DB_CLI" sql "UPDATE specs SET branch = NULL WHERE id = $spec_id;"

    echo "{\"success\": true, \"aborted\": true}"
}

list_worktrees() {
    cd "$MAIN_PROJECT"
    git worktree list --porcelain | grep -E "^(worktree|branch)" | paste - - | \
        awk '{print "{\"path\": \"" $2 "\", \"branch\": \"" $4 "\"}"}'
}

worktree_status() {
    local spec_id="$1"
    local worktree_path=$(get_worktree_path "$spec_id")
    local branch_name=$(get_branch_name "$spec_id")

    if [[ ! -d "$worktree_path" ]]; then
        echo "{\"exists\": false}"
        return
    fi

    cd "$worktree_path"

    local uncommitted=$(git status --porcelain | wc -l | tr -d ' ')
    local ahead=$(git rev-list --count main.."$branch_name" 2>/dev/null || echo "0")
    local has_remote=$(git ls-remote --heads origin "$branch_name" 2>/dev/null | wc -l | tr -d ' ')

    echo "{\"exists\": true, \"path\": \"$worktree_path\", \"uncommitted\": $uncommitted, \"commits_ahead\": $ahead, \"pushed\": $([[ $has_remote -gt 0 ]] && echo true || echo false)}"
}

worktree_path() {
    local spec_id="$1"
    get_worktree_path "$spec_id"
}

case "${1:-}" in
    create)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 create <spec_id>"; exit 1; }
        create_worktree "$2"
        ;;
    cleanup)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 cleanup <spec_id>"; exit 1; }
        cleanup_worktree "$2"
        ;;
    merge)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 merge <spec_id>"; exit 1; }
        merge_worktree "$2"
        ;;
    abort)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 abort <spec_id>"; exit 1; }
        abort_worktree "$2"
        ;;
    list)
        list_worktrees
        ;;
    status)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 status <spec_id>"; exit 1; }
        worktree_status "$2"
        ;;
    path)
        [[ -z "${2:-}" ]] && { echo "Usage: $0 path <spec_id>"; exit 1; }
        worktree_path "$2"
        ;;
    *)
        show_help
        ;;
esac
