#!/bin/bash

# =============================================================================
# CONFIGURATION - Update these values for your machine
# =============================================================================
WORKTREE_BASE_DIR="/Users/bracesproul/code/lang-chain-ai/wt"
INSTALL_COMMAND="uv sync && uv run poe install-deps"
# =============================================================================

# Exit if no branch name supplied
if [ -z "$1" ]; then
  echo "Error: No branch name supplied."
  echo "Usage: wtc <branch_name> [--yolo] [--codex]"
  return 1
fi

# Variables
BRANCH_NAME=$1
WORKTREE_DIR="$WORKTREE_BASE_DIR/$BRANCH_NAME"
YOLO=false
USE_CODEX=false

# Parse arguments
shift # Remove branch name from arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --yolo)
      YOLO=true
      shift
      ;;
    --codex)
      USE_CODEX=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      return 1
      ;;
  esac
done

# Create git worktree (and branch if it doesn't exist)
if git show-ref --verify --quiet refs/heads/$BRANCH_NAME; then
  echo "Branch '$BRANCH_NAME' exists. Creating worktree..."
  git worktree add $WORKTREE_DIR $BRANCH_NAME
else
  echo "Creating new branch '$BRANCH_NAME' and worktree..."
  git worktree add -b $BRANCH_NAME $WORKTREE_DIR
fi

# Error handling for git worktree
if [ $? -ne 0 ]; then
  echo "Git worktree creation failed."
  return 1
fi

# Function to copy env files
copy_env_files() {
  local SOURCE_BASE_DIR=$1

  echo "Copying .env files to worktree directory..."

  # Find all .env files in the source directory and copy them to the worktree directory
  find "$SOURCE_BASE_DIR" -type f \( -name ".env" -o -name ".env.local" -o -name "credentials.json" \) | while read -r file; do
    # Get the relative path from the source base directory
    relative_path="${file#$SOURCE_BASE_DIR/}"

    # Create the destination directory if it doesn't exist
    dest_dir="$WORKTREE_DIR/${relative_path%/*}"
    mkdir -p "$dest_dir"

    # Copy the file
    cp "$file" "$dest_dir/"
    echo "Copied: '$file' to '$dest_dir/'"
  done

  echo "Copied .env files successfully."
}

# Get the current directory as the source base directory
SOURCE_BASE_DIR="$(pwd)"
copy_env_files "$SOURCE_BASE_DIR"

# Copy top-level secrets directory if it exists
if [ -d "$SOURCE_BASE_DIR/secrets" ]; then
  echo "Copying secrets directory to worktree directory..."
  rsync -a "$SOURCE_BASE_DIR/secrets/" "$WORKTREE_DIR/secrets/"
  if [ $? -ne 0 ]; then
    echo "Secrets directory copy failed."
    return 1
  fi
  echo "Copied secrets directory successfully."
fi

# Navigate to worktree directory
cd $WORKTREE_DIR

# Error handling for cd command
if [ $? -ne 0 ]; then
  echo "Failed to change directory."
  return 1
fi

echo "Worktree created successfully."

# Run install command
echo "Running $INSTALL_COMMAND..."
eval "$INSTALL_COMMAND"

if [ $? -ne 0 ]; then
  echo "Install command failed."
  return 1
fi

echo "Install command completed successfully."

# Run AI assistant
if [ "$USE_CODEX" = true ]; then
  echo "Starting codex..."
  if [ "$YOLO" = true ]; then
    codex --full-auto
  else
    codex
  fi
else
  echo "Starting claude..."
  if [ "$YOLO" = true ]; then
    claude --dangerously-skip-permissions
  else
    claude
  fi
fi
