import { MerkleTree } from "merkletreejs";
import keccak256 from "keccak256";
import csv from "csv-parser";
import fs from "fs";
import { utils } from "ethers";

function main() {
  let root: string;

  // Files for each airdrop
  const filename = "script/typescript/gen_files/phase1_addresses.csv";
  const output_file = "script/typescript/gen_files/freeMerkleProof.json";

  // Used to store one leaf for each line in the distribution file
  const token_dist: string[] = [];

  // Used for tracking user_id of each leaf so we can write to proofs file accordingly
  const user_dist_list: [string][] = [];

  // Open distribution CSV
  fs.createReadStream(filename)
    .pipe(csv())
    .on("data", (row: { [key: string]: string }) => {
      const user_dist: [string] = [row["user_address"]]; // Create record to track user_id of leaves
      const leaf_hash = utils.solidityKeccak256(
        ["address"],
        [row["user_address"]]
      ); // Encode base data like solidity abi.encode
      user_dist_list.push(user_dist); // Add record to index tracker
      token_dist.push(leaf_hash); // Add leaf hash to distribution
    })
    .on("end", () => {
      // Create Merkle tree from token distribution
      const merkle_tree = new MerkleTree(token_dist, keccak256, {
        sortPairs: true,
      });

      // Get root of our tree
      root = merkle_tree.getHexRoot();

      // Create proof file
      write_leaves(merkle_tree, user_dist_list, token_dist, root);
    });

  // Write leaves & proofs to JSON file
  function write_leaves(
    merkle_tree: MerkleTree,
    user_dist_list: [string][],
    token_dist: string[],
    root: string
  ) {
    console.log("Begin writing leaves to file...");

    const full_dist: { [key: string]: { leaf: string; proof: string[] } } = {};
    // const full_user_claim: { [key: string]: { address: string } } = {};

    for (let line = 0; line < user_dist_list.length; line++) {
      // Generate leaf hash from raw data
      const leaf = token_dist[line];

      // Create dist object
      const user_dist = {
        leaf: leaf,
        proof: merkle_tree.getHexProof(leaf),
      };

      // Add record to our distribution
      full_dist[user_dist_list[line][0]] = user_dist;
    }

    const merkleRoot = {
      root
    }
    const merkleTree = Object.assign(full_dist, merkleRoot);

    fs.writeFile(output_file, JSON.stringify(merkleTree, null, 4), (err) => {
      if (err) {
        console.error(err);
        return;
      }

      console.log(
        `${output_file} has been written with a root hash of:\n${root}`
      );
    });
  }
}

main();
