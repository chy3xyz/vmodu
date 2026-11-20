#!/bin/bash

# Fix enum comparison errors
echo "Fixing enum comparisons..."
sed -i '' 's/if level < l.config.level/if int(level) < int(l.config.level)/g' vmodu_modules/infra/logger/logger.v

# Fix health.v enum comparisons  
sed -i '' 's/if overall_status == .healthy/if int(overall_status) == int(Status.healthy)/g' vmodu_modules/infra/health/health.v
sed -i '' 's/overall_status = .degraded/overall_status = Status.degraded/g' vmodu_modules/infra/health/health.v
sed -i '' 's/overall_status = .unhealthy/overall_status = Status.unhealthy/g' vmodu_modules/infra/health/health.v

# Fix metrics.v immutable receivers
echo "Fixing metrics immutable receivers..."
for obj in c g h e; do
    sed -i '' "s/${obj}.mu.lock()/unsafe { ${obj}.mu.lock() }/g" vmodu_modules/infra/metrics/metrics.v
    sed -i '' "s/${obj}.mu.unlock()/unsafe { ${obj}.mu.unlock() }/g" vmodu_modules/infra/metrics/metrics.v
    sed -i '' "s/${obj}.mu.rlock()/unsafe { ${obj}.mu.rlock() }/g" vmodu_modules/infra/metrics/metrics.v
    sed -i '' "s/${obj}.mu.runlock()/unsafe { ${obj}.mu.runlock() }/g" vmodu_modules/infra/metrics/metrics.v
done

# Fix empty map initialization
echo "Fixing empty map initialization..."
sed -i '' 's/{}/map[string]string{}/g' vmodu_modules/infra/metrics/metrics.v

echo "Done!"
