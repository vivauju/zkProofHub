# zkProof-as-a-Service Smart Contract

A plug-and-play zero-knowledge proof verification service built on Stacks blockchain, providing developers with easy-to-integrate zk tooling without the complexity of implementing verification infrastructure.

## 🌟 Features

- **Multiple ZK Proof Types**: Support for zk-SNARKs, zk-STARKs, Bulletproofs, and PLONK
- **Verifier Network**: Decentralized network of registered verifiers with reputation scoring
- **Flexible Pricing**: Configurable fees per proof type with extension options
- **Batch Operations**: Efficient batch verification for multiple proofs
- **User Analytics**: Comprehensive statistics tracking for users and verifiers
- **Challenge System**: Built-in dispute resolution for verification challenges
- **Admin Controls**: Pausable contract with fee management capabilities

## 📋 Table of Contents

- [Quick Start](#quick-start)
- [Contract Architecture](#contract-architecture)
- [Core Functions](#core-functions)
- [Proof Types](#proof-types)
- [Verifier Registration](#verifier-registration)
- [Fee Structure](#fee-structure)
- [API Reference](#api-reference)
- [Error Codes](#error-codes)
- [Deployment](#deployment)
- [Contributing](#contributing)

## 🚀 Quick Start

### For Proof Submitters

1. **Submit a Proof**:
```clarity
(contract-call? .zkproof-service submit-proof 
  "zk-snark"                    ;; proof type
  0x1234...                     ;; proof hash (32 bytes)
  0xabcd...                     ;; public inputs (up to 1024 bytes)
  0xef01...                     ;; verification key (up to 512 bytes)
  u144)                         ;; expiry in blocks (~24 hours)
```

2. **Check Verification Status**:
```clarity
(contract-call? .zkproof-service is-proof-verified u1)
```

### For Verifiers

1. **Register as a Verifier**:
```clarity
(contract-call? .zkproof-service register-verifier 
  "My Verification Service"
  (list "zk-snark" "bulletproof"))
```

2. **Verify Proofs**:
```clarity
(contract-call? .zkproof-service verify-proof u1 true)
```

## 🏗️ Contract Architecture

### Data Storage

- **Proofs Map**: Stores proof metadata, verification status, and expiry
- **Verifiers Map**: Manages verifier registry with reputation scores
- **User Stats**: Tracks individual user activity and success rates
- **Proof Types**: Configurable proof type settings and fees

### Key Components

1. **Proof Lifecycle Management**: From submission to verification
2. **Verifier Reputation System**: Score-based verifier ranking
3. **Fee Management**: Dynamic pricing with extension options
4. **Security Controls**: Owner permissions and emergency pause

## 🔧 Core Functions

### Proof Operations

| Function | Description | Fee Required |
|----------|-------------|--------------|
| `submit-proof` | Submit a new ZK proof for verification | Yes (varies by type) |
| `verify-proof` | Verify a submitted proof (verifiers only) | No |
| `batch-verify-proofs` | Verify multiple proofs efficiently | No |
| `challenge-verification` | Challenge an existing verification | No |
| `extend-proof-expiry` | Extend proof expiration time | Yes (10% of service fee) |

### Query Functions

| Function | Description |
|----------|-------------|
| `get-proof` | Retrieve proof details by ID |
| `get-verifier` | Get verifier information |
| `get-user-stats` | Check user activity statistics |
| `is-proof-verified` | Quick verification status check |

## 📝 Proof Types

| Type | Min Fee | Default Timeout | Description |
|------|---------|----------------|-------------|
| `zk-snark` | 0.5 STX | 24 hours | Succinct Non-Interactive Arguments |
| `zk-stark` | 0.75 STX | 24 hours | Scalable Transparent Arguments |
| `bulletproof` | 0.3 STX | 12 hours | Short Non-Interactive Zero-Knowledge |
| `plonk` | 0.6 STX | 24 hours | Permutations over Lagrange-bases |

## 👥 Verifier Registration

### Requirements
- No minimum stake required (configurable per proof type)
- Must specify supported proof types
- Automatic reputation score initialization (100 points)

### Reputation System
- Starts at 100 points (neutral)
- +1 point for successful verifications
- Score affects verifier selection probability
- Total verification count tracked

### Registration Process
```clarity
(contract-call? .zkproof-service register-verifier 
  "Verifier Name (max 64 chars)"
  (list "supported" "proof" "types"))
```

## 💰 Fee Structure

### Base Fees
- **Service Fee**: 1 STX (configurable by admin)
- **Proof-Specific Fees**: Varies by complexity
- **Extension Fee**: 10% of service fee per extension

### Fee Distribution
- Collected fees held in contract
- Admin withdrawal available to contract owner
- Future: Planned verifier reward distribution

## 📚 API Reference

### Data Structures

#### Proof Object
```clarity
{
  submitter: principal,
  proof-type: (string-ascii 32),
  proof-hash: (buff 32),
  public-inputs: (buff 1024),
  verification-key: (buff 512),
  verified: bool,
  verifier: (optional principal),
  timestamp: uint,
  expiry: uint
}
```

#### Verifier Object
```clarity
{
  name: (string-ascii 64),
  supported-types: (list 10 (string-ascii 32)),
  reputation-score: uint,
  total-verifications: uint,
  active: bool
}
```

#### User Stats Object
```clarity
{
  total-proofs: uint,
  verified-proofs: uint,
  last-activity: uint
}
```

### Admin Functions

| Function | Description | Access |
|----------|-------------|---------|
| `initialize-contract` | Set up default proof types | Owner only |
| `add-proof-type` | Add new proof type configuration | Owner only |
| `set-service-fee` | Update base service fee | Owner only |
| `pause-contract` | Emergency pause all operations | Owner only |
| `unpause-contract` | Resume contract operations | Owner only |
| `withdraw-fees` | Withdraw collected fees | Owner only |

## ❌ Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | `ERR_UNAUTHORIZED` | Caller lacks required permissions |
| u101 | `ERR_PROOF_NOT_FOUND` | Specified proof ID does not exist |
| u102 | `ERR_INVALID_PROOF` | Proof data or state is invalid |
| u103 | `ERR_PROOF_ALREADY_EXISTS` | Proof already verified |
| u104 | `ERR_INSUFFICIENT_PAYMENT` | Insufficient STX for fees |
| u105 | `ERR_VERIFIER_NOT_REGISTERED` | Verifier not in registry |
| u106 | `ERR_INVALID_PROOF_TYPE` | Unsupported proof type |

## 🚀 Deployment

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Clarity CLI or Clarinet development environment
- STX for deployment transaction fees

### Deployment Steps

1. **Deploy Contract**:
```bash
clarinet deploy --network testnet
```

2. **Initialize Contract**:
```clarity
(contract-call? .zkproof-service initialize-contract)
```

3. **Configure Additional Proof Types** (if needed):
```clarity
(contract-call? .zkproof-service add-proof-type 
  "custom-type" u1000000 u72 false)
```

### Environment Configuration

```toml
# Clarinet.toml
[network.testnet]
stacks_node_rpc_address = "https://stacks-node-api.testnet.stacks.co"
deployment_fee_rate = 10

[network.mainnet]
stacks_node_rpc_address = "https://stacks-node-api.mainnet.stacks.co"
deployment_fee_rate = 1
```

## 🛡️ Security Considerations

- **Access Control**: Owner-only administrative functions
- **Input Validation**: All inputs validated before processing
- **Reentrancy Protection**: Safe transfer patterns used
- **Emergency Controls**: Pausable contract functionality
- **Expiry Management**: Time-based proof lifecycle management

## 🤝 Contributing

### Development Setup
1. Install [Clarinet](https://github.com/hirosystems/clarinet)
2. Clone repository
3. Run tests: `clarinet test`
4. Submit pull requests with comprehensive tests

### Code Standards
- Follow Clarity best practices
- Include comprehensive error handling
- Document all public functions
- Write unit tests for new features
