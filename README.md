📄 README.md
markdown
Copy
Edit
# 🎓 SimbiToken & StudyAchievements Contracts

This repository contains the smart contracts for **SimbiToken** (an ERC20 token with governance and rewards) and **StudyAchievements** (an NFT badge system for academic achievements). The contracts are deployed to the **Ethereum Sepolia Testnet** and fully verified on Etherscan.

---

## 🚀 Deployment Summary

**Deployer Account:** `0xa8d1dad477b15e5052a12b7475C5966e48C08c48`

### ✅ Deployed Contracts

| Contract           | Address                                      | Etherscan Verified Link                                                                 |
|--------------------|----------------------------------------------|------------------------------------------------------------------------------------------|
| StudyAchievements  | `0x21de584eA6CfE460F0Dc89e9469507C2454cb635` | [View on Sepolia](https://sepolia.etherscan.io/address/0x21de584eA6CfE460F0Dc89e9469507C2454cb635#code) |
| SimbiToken         | `0x288167e166ecc5AD872b44c218744Ee4d35b08bb` | [View on Sepolia](https://sepolia.etherscan.io/address/0x288167e166ecc5AD872b44c218744Ee4d35b08bb#code) |

---

## 🛠️ Getting Started with Hardhat

### 📦 Prerequisites

Make sure you have the following installed:

- Node.js (v18+ recommended)
- pnpm / npm / yarn
- Hardhat
- Metamask (for testnet deployment and contract interaction)

---

## 📁 Project Setup

1. **Clone the Repository**

```bash
git clone https://github.com/your-username/simbi-web3.git
cd simbi-web3
Install Dependencies
```
```bash
pnpm install
# or
npm install
```

Setup Environment Variables

Copy the example file and configure your secrets:

```bash
cp .env.example .env
Update .env with your Sepolia RPC URL and Private Key.
```

🧪 Compile Contracts
```bash

npx hardhat compile
```

🚀 Deploy Contracts to Sepolia
```bash

npx hardhat run scripts/deploy.ts --network sepolia
```
This script will:

Deploy both StudyAchievements and SimbiToken

Automatically verify both contracts on Sepolia Etherscan

Print deployed addresses and verification links

🔍 Contract Verification (Manual Option)
```bash

npx hardhat verify --network sepolia <CONTRACT_ADDRESS> <constructor args>
```
💻 Environment Variables
All secrets and sensitive values are managed through a .env file (example below).

🧪 Test (Optional)
If you have tests:

```bash

npx hardhat test
```
✅ Status
 StudyAchievements Deployed & Verified

 SimbiToken Deployed & Verified

 Integrated Deployment + Verification Script

 Ready for backend integration

🙌 Final Note
Our final updated and deployed contracts from the Web3 team 💯
Now integrations with the backend resume to connect the Web3 and Web2 systems.
Good day, guys — and HAPPY HACKING! 🧑‍💻🔥

yaml


---

### 📄 `.env.example`

```env
# .env.example

# Sepolia RPC endpoint (from Alchemy, Infura, etc.)
SEPOLIA_RPC_URL=https://sepolia.infura.io/v3/YOUR_INFURA_PROJECT_ID

# Private key of your deployer wallet (used ONLY for deployment)
PRIVATE_KEY=your-wallet-private-key
