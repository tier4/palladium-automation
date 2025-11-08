# Task Completion Checklist

When completing a task in this project, follow this checklist:

## 1. Code Quality

### For Hornet RTL Changes
- [ ] Syntax check passes (Verible lint if available)
- [ ] No introduce new lint warnings
- [ ] Follow hornet coding conventions
- [ ] Add/update comments for complex logic

### For Automation Scripts
- [ ] Script has proper error handling
- [ ] Script is executable (`chmod +x`)
- [ ] Script tested locally if possible

## 2. Testing

### For RTL Changes
- [ ] Identify affected test cases
- [ ] Generate test script for ga53pd01
- [ ] Execute via `./scripts/claude_to_ga53pd01.sh`
- [ ] Verify simulation passes
- [ ] Check for timing violations or warnings

### For Script Changes
- [ ] Test with sample input
- [ ] Verify error handling
- [ ] Check result archiving works

## 3. Documentation

- [ ] Update CLAUDE.md if workflow changes
- [ ] Update README.md if user-facing changes
- [ ] Add comments to complex code sections
- [ ] Document any new environment variables or dependencies

## 4. Git Operations

### For hornet/ changes
```bash
cd hornet
git status
git add <modified files>
git commit -m "description"
# Decide whether to push to upstream
```

### For palladium-automation changes
```bash
git status
git add .
git commit -m "type: description

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
```

## 5. Result Archiving

- [ ] Execution results saved to workspace/etx_results/.archive/
- [ ] Results filename includes timestamp and task description
- [ ] Critical results documented or copied to permanent location

## 6. Cleanup

- [ ] Remove temporary scripts from /tmp/
- [ ] No sensitive data (passwords, tokens) in committed files
- [ ] ga53pd01 working directory cleaned if needed
