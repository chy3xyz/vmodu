# Frequently Asked Questions (FAQ)

## General Questions

### What is VModulith Runtime?

VModulith Runtime is an AI Native Backend Operating System built in Vlang. It combines:
- Actor Model for high-performance concurrency
- Event-driven architecture
- AI Agent orchestration
- Web3 native support

### Why Vlang?

Vlang provides:
- Zero-cost abstractions
- Compile-time memory safety
- C-like performance
- Small binary sizes (~200KB)
- Fast compilation

### What can I build with VModulith?

- DeFi trading engines
- AI agent infrastructure
- Real-time multiplayer games
- High-frequency trading systems
- Distributed messaging platforms

## Getting Started

### How do I install VModulith?

```bash
# From source
git clone https://github.com/vmodu/runtime.git
cd vmodu-runtime
make install

# Or download binary
curl -L https://vmodu.io/install.sh | bash
```

See [INSTALL.md](../INSTALL.md) for details.

### What are the system requirements?

**Minimum:**
- 2 CPU cores
- 2GB RAM
- Linux/macOS/Windows WSL

**Recommended:**
- 8+ CPU cores
- 8GB+ RAM
- SSD storage

### How do I update VModulith?

```bash
# Check current version
vmodu --version

# Update to latest
vmodu update

# Or from source
git pull
make build
make install
```

## Architecture

### How many actors can VModulith handle?

1,000,000+ actors on a single machine, using ~100 bytes per actor.

### Is VModulith distributed?

Yes! v2.2.0+ includes:
- Multi-node clusters
- Raft consensus
- Actor migration
- Sharding support

### Can I run VModulith in Docker?

Yes:

```bash
docker run -p 8080:8080 vmodu/runtime:latest
```

See [deployment guide](deployment.md).

## Configuration

### How do I configure VModulith?

Configuration file: `~/.config/vmodu/config.json`

```json
{
  "gateway": {
    "http_port": 8080
  },
  "runtime": {
    "scheduler_workers": 16
  }
}
```

Or use environment variables:

```bash
export VMODU_HTTP_PORT=8080
export VMODU_SCHEDULER_WORKERS=16
```

### Where are logs stored?

Default: `/var/log/vmodu/`

Configure in `config.json`:

```json
{
  "logging": {
    "file": "/var/log/vmodu/vmodu.log",
    "level": "info"
  }
}
```

### How do I change the data directory?

```bash
vmodu --data-dir /mnt/data/vmodu

# Or in config
{
  "event": {
    "store_path": "/mnt/data/vmodu/events"
  }
}
```

## Performance

### How fast is VModulith?

- **Message throughput**: 1M+ messages/second
- **Latency (p99)**: < 1ms
- **Actor creation**: 1M+ actors/second

### How do I tune performance?

1. Increase scheduler workers:
   ```json
   {"runtime": {"scheduler_workers": 32}}
   ```

2. Tune kernel parameters:
   ```bash
   echo "net.core.somaxconn = 65535" | sudo tee -a /etc/sysctl.conf
   ```

3. Use SSD for event storage

See [performance guide](performance.md).

### Why is my performance lower than expected?

Common causes:
- Insufficient file descriptors (`ulimit -n`)
- Not enough scheduler workers
- Slow disk I/O
- Network latency (for cluster)

## Web3 Integration

### Which blockchains are supported?

- **EVM**: Ethereum, Polygon, BSC, Arbitrum, Optimism
- **Solana**: Mainnet, Devnet
- More coming soon!

### How do I connect to Ethereum?

```json
{
  "adapters": {
    "evm": {
      "rpc_url": "https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
    }
  }
}
```

### Can I use my own Ethereum node?

Yes:

```json
{
  "adapters": {
    "evm": {
      "rpc_url": "http://localhost:8545"
    }
  }
}
```

### How are private keys managed?

Options:
1. Environment variables
2. Hardware wallets (Ledger, Trezor)
3. AWS KMS / HashiCorp Vault
4. Encrypted key files

## AI Integration

### Which LLMs are supported?

- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- Local models (via API)

### How do I configure LLM?

```bash
export OPENAI_API_KEY=sk-...
```

Or in config:

```json
{
  "llm": {
    "provider": "openai",
    "api_key": "${OPENAI_API_KEY}",
    "model": "gpt-4"
  }
}
```

### Can I use local LLMs?

Yes, if they expose an OpenAI-compatible API:

```json
{
  "llm": {
    "provider": "openai",
    "base_url": "http://localhost:8000/v1"
  }
}
```

## Troubleshooting

### VModulith won't start

Check:
1. Port availability: `sudo lsof -i :8080`
2. File permissions: `ls -la /data/vmodu`
3. Config syntax: `vmodu --config-check`
4. Logs: `journalctl -u vmodu -f`

### "Out of memory" errors

Solutions:
- Reduce `max_actors` in config
- Decrease mailbox sizes
- Add more RAM
- Enable swap (temporary)

### Cluster nodes can't connect

Check:
1. Firewall rules
2. Network connectivity: `ping <node>`
3. Port accessibility: `telnet <node> 9000`
4. Log for errors: `grep -i cluster /var/log/vmodu/vmodu.log`

### High CPU usage

1. Profile: `vmodu --profile-cpu`
2. Check for infinite loops in custom code
3. Reduce worker count if oversubscribed

## Development

### How do I write a custom module?

```v
module my_module

import core.modulith

pub struct MyModule {
    modulith.BaseModule
}

pub fn (m MyModule) name() string {
    return "my_module"
}

pub fn (m MyModule) init() ! {
    println("My module initialized")
}

pub fn (m MyModule) handle(msg actor.Message) {
    // Process message
}
```

### How do I test my code?

```bash
# Run all tests
v test .

# Run specific test
v test -run test_my_feature

# With coverage
v -coverage test .
```

### How do I contribute?

See [CONTRIBUTING.md](../CONTRIBUTING.md).

1. Fork repository
2. Create feature branch
3. Write tests
4. Submit PR

## Licensing

### What license is VModulith under?

MIT License - free for commercial and personal use.

### Can I use VModulith in commercial projects?

Yes! No restrictions.

## Support

### Where can I get help?

- Documentation: [docs.vmodu.io](https://docs.vmodu.io)
- Discord: [discord.gg/vmodu](https://discord.gg/vmodu)
- GitHub Issues: [github.com/vmodu/runtime/issues](https://github.com/vmodu/runtime/issues)
- Email: support@vmodu.io

### How do I report a bug?

1. Search existing issues
2. Create new issue with:
   - VModulith version
   - V version
   - OS details
   - Steps to reproduce
   - Expected vs actual behavior
   - Logs

### Is there a paid support option?

Yes! Contact enterprise@vmodu.io for:
- Priority support
- Custom development
- Training
- Consulting

## Roadmap

### What's coming next?

- WASM component model support
- More blockchain integrations
- Enhanced AI capabilities
- WebAssembly System Interface (WASI)
- Zero-knowledge proof integration

### When is v3.1.0 coming?

Check [CHANGELOG.md](../CHANGELOG.md) and GitHub milestones.

---

**Still have questions?**

- Join our [Discord community](https://discord.gg/vmodu)
- Open an issue on [GitHub](https://github.com/vmodu/runtime)
- Email: support@vmodu.io
