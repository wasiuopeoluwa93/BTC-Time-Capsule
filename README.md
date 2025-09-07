📜 BTC Time Capsule Smart Contract
Overview

The BTC Time Capsule is a Clarity smart contract that enables users to create, lock, and unlock time-based capsules on the Stacks blockchain. Capsules can contain messages, NFTs, or a hybrid of both, and are only accessible after a specified block height or through an emergency unlock mechanism (with penalty).

It provides a decentralized way to preserve digital content (messages or NFTs) until a predetermined time in the future, acting like a blockchain-based "time capsule."

✨ Features

Capsule Types:

Message Capsule → Stores a text message, locked until a future block height.

NFT Capsule → Stores metadata for an NFT (name, description, image).

Hybrid Capsule → Stores both a message and NFT in a single capsule.

Ownership & Transfer:

Capsules can be transferred to new owners before unlock.

Capsules can include a beneficiary who can unlock them at the specified height.

Unlocking:

Standard Unlock: Capsule content becomes available after the unlock block height.

Emergency Unlock: Capsule can be unlocked early with a 10% penalty fee.

NFT Integration (SIP-009):

Compliant NFT ownership transfer system.

Capsules linked with NFTs are tracked with metadata.

User & Capsule Management:

Track capsules owned by each user.

Ability to query capsule metadata, messages, and NFTs.

Administrative Controls:

Set and update creation fees.

Toggle emergency unlock availability.

Define a global contract URI for metadata or frontend integration.

📂 Data Structures

time-capsules: Stores all capsule details (owner, beneficiary, unlock height, type, etc.).

nft-metadata: Stores NFT details (name, description, image, linked capsule).

capsule-owners: Maps NFTs to their current owners.

user-capsules: Tracks capsule IDs per user.

emergency-unlocks: Records details of early unlocks.

🔑 Public Functions

Capsule Creation:

create-message-capsule

create-nft-capsule

create-hybrid-capsule

Capsule Interaction:

unlock-capsule → Unlock at block height.

emergency-unlock → Unlock early with penalty.

transfer-capsule → Transfer ownership.

set-beneficiary → Assign or update a beneficiary.

get-unlocked-content → Retrieve capsule content.

NFT (SIP-009):

transfer → Transfer NFTs.

mint → Mint new NFTs (admin-only).

Admin Controls:

set-creation-fee

toggle-emergency-unlock

set-contract-uri

📊 Read-only Functions

Capsule information: get-capsule, get-capsule-metadata, is-capsule-unlockable, get-user-capsules.

NFT information: get-owner, get-token-uri, get-last-token-id.

Contract state: get-total-capsules, get-total-nfts, get-current-block-height.

Utility: calculate-emergency-penalty, get-capsules-by-category (off-chain indexing suggested).

🚀 Example Flow

Create a Capsule
User pays the creation fee to store a message or NFT with a chosen unlock block height.

Wait Until Unlock
Capsule remains locked until the blockchain reaches the specified height.

Unlock

Owner or beneficiary unlocks it at the block height.

Alternatively, they can use emergency unlock with a penalty.

Retrieve Content
Once unlocked, message and/or NFT content becomes accessible.

⚡ Deployment Notes

Ensure SIP-009 compliance for NFT integration.

Off-chain indexing is recommended for category searches.

Capsule lists per user are limited to 100 capsules.

🛠️ Use Cases

Digital Time Capsules: Lock personal messages or family letters until a milestone date.

Legacy NFTs: Transfer NFTs or artworks to beneficiaries at a future block height.

Event-Based Unlocking: Create digital treasures that become accessible after blockchain-defined events.

Emergency Unlock Mechanism: Provides flexibility while penalizing premature access.