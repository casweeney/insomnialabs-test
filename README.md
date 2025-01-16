## Multi Utility NFT Contract
This repository contains the smart contract implementation of a Multi Utility NFT which has 3 phases of minting for different categories of users.

## Documentation
The smart contract is made up of 3 minting phases:

### Phase1 Minting
Whitelisted users who are verified using a Merkle root can mint an NFT for. The contract was implemented such that, a free minting user can only mint an NFT once.

### Phase2 Minting
The phase minting process requires that selected users who are verified using a Merkle root can mint at discounted price, but the criterion for minting is that they must provide a valid signature from the smart contract owner before they can mint an NFT. The contract was implemented such that a valid signature can only be used once.

### Phase3 Minting
This is last minting stage, where anyone can mint an NFT at the full NFT price. Here there is no restriction to mint, users can mint as many NFTs they want, and they pay for every mint.

### Vesting
After the minting process is done, the owner of the contract can lock the fee collected from minters in a linear vesting schedule for a year on Sablier protocol. Only the owner of the contract can withdraw the vested tokens. The owner can only create vesting and withdraw vesting during the Vesting phase.

## Usage
To clone the repo, run:
```sh
git clone https://github.com/casweeney/insomnialabs-test.git
```

After clone the repo, run the following command to build it:

```sh
$ forge build
```

### Test
The smart contract was properly tested using Branching Tree Technique (BTT). In order to carryout effective testing, TypeScript was used to generate Merkle proofs and root from a `csv` file containing a list of selected addresses.
- Two csv files `phase1_addresses.csv` and `phase2_addresses.csv` were created to effectively handle the selected/whitelisted users for phase1 and phase1 respectively.
- To generate the Merkle proof for the phase 1 users, run: `yarn generate-free`. This will generate a `freeMerkleProof.json` located at `script/typescript/gen_files`
- To generate the Merkle proof for th phase 2 users, run `yarn generate-discount`. It will also generate a `discountMerkleProof.json` located at `script/typescript/gen_files`
- The scripts responsible for generation the proofs are `freeMerkle.ts` and `discountMerkle.ts` respectively.

- Before you run the test for this repository, create a `.env` file, use the variable provided in the `.env.example` and set a value. This is required for the fork tests, because we are forking Ethereum mainnet to interact with SablierV2LockupLinear contract.
Run:
```shell
$ forge test
```