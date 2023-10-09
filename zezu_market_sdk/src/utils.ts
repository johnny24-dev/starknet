import { concat, keccak256, randomBytes, toUtf8Bytes } from "ethers";

export const generateRandomSalt = (domain?: string) => {
    if (domain) {
      return `0x${Buffer.from(
        concat([
          keccak256(toUtf8Bytes(domain)).slice(0, 10),
          Uint8Array.from(Array(20).fill(0)),
          randomBytes(8),
        ]),
      ).toString("hex")}`;
    }
    return `0x${Buffer.from(randomBytes(8)).toString("hex").padStart(64, "0")}`;
  };