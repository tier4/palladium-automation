# Suggested Commands

## Remote Execution

### Execute script on ga53pd01 (SSH sync mode - recommended)
```bash
./scripts/claude_to_ga53pd01.sh /path/to/script.sh
```
- **Duration**: 2-3 seconds
- **Output**: Real-time display + saved to workspace/etx_results/.archive/YYYYMM/
- **Use case**: Standard builds, tests, short simulations

### GitHub async execution (for long-running tasks)
```bash
USE_GITHUB=1 ./scripts/claude_to_ga53pd01.sh /path/to/long_script.sh
```
- **Duration**: 10-30 seconds (polling overhead)
- **Output**: Saved to GitHub temporarily + local archive
- **Use case**: Long simulations, overnight runs

## Hornet Development

### Update hornet repository
```bash
cd hornet
git fetch origin
git pull origin main
```

### Check hornet status
```bash
cd hornet
git status
git log --oneline -10
```

## Result Management

### View recent results
```bash
ls -lt workspace/etx_results/.archive/$(date +%Y%m)/ | head -20
```

### Search result archives
```bash
find workspace/etx_results/.archive/ -name "*hornet*" -mtime -7
```

## SSH Management

### Test SSH connection
```bash
ssh ga53pd01 hostname
```

### Check SSH config
```bash
cat ~/.ssh/config | grep -A 5 ga53pd01
```

## Git Operations (palladium-automation)

### Commit changes
```bash
git add .
git commit -m "description"
```

### View status
```bash
git status
git log --oneline -10
```
