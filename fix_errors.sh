#!/bin/bash
# Fix common V language errors in vmodu_modules

cd /Users/n0x/ws_clawworld/vmodu_runtime/vmodu_modules

# Fix 1: immutable receiver with mutex - use unsafe block
echo "Fixing immutable receiver errors..."
find . -name "*.v" -exec sed -i '' 's/pub fn (c \&Checker)/pub fn (c \&Checker)/g' {} \;

# Fix 2: Add unsafe to mutex operations in immutable receivers  
for file in infra/health/health.v infra/db/event_store.v; do
    if [ -f "$file" ]; then
        # Replace c.mu.rlock()/runlock() with unsafe blocks
        sed -i '' 's/c\.mu\.rlock()/unsafe { c.mu.rlock() }/g' "$file"
        sed -i '' 's/c\.mu\.runlock()/unsafe { c.mu.runlock() }/g' "$file"
        sed -i '' 's/c\.mu\.lock()/unsafe { c.mu.lock() }/g' "$file"
        sed -i '' 's/c\.mu\.unlock()/unsafe { c.mu.unlock() }/g' "$file"
        
        # For pl (PersistentLog)
        sed -i '' 's/pl\.mu\.rlock()/unsafe { pl.mu.rlock() }/g' "$file"
        sed -i '' 's/pl\.mu\.runlock()/unsafe { pl.mu.runlock() }/g' "$file"
        sed -i '' 's/pl\.mu\.lock()/unsafe { pl.mu.lock() }/g' "$file"
        sed -i '' 's/pl\.mu\.unlock()/unsafe { pl.mu.unlock() }/g' "$file"
    fi
done

echo "Done with basic fixes"
