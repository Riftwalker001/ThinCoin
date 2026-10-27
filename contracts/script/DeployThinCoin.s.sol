// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "../src/ThinPoWToken.sol";
import "../src/ThinStakingLocker.sol";
import "../src/ThinLPLocker.sol";

contract DeployThinCoin is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy ThinPoWToken with 100,000 THIN genesis allocation for LP seeding & Dev Staking Lock
        uint256 genesisSupply = 100_000 ether;
        ThinPoWToken token = new ThinPoWToken(deployer, genesisSupply);

        // 2. Deploy ThinStakingLocker for Dev Loyalty Staking Lock
        ThinStakingLocker stakingLocker = new ThinStakingLocker(address(token), deployer);

        // 3. Deploy ThinLPLocker for Uniswap LP TimeLock
        ThinLPLocker lpLocker = new ThinLPLocker();

        vm.stopBroadcast();

        console.log("--------------------------------------------------");
        console.log("THIN COIN DEPLOYMENT SUMMARY:");
        console.log("Token Contract:          ", address(token));
        console.log("Dev Staking Locker:      ", address(stakingLocker));
        console.log("Uniswap LP Locker:       ", address(lpLocker));
        console.log("Genesis Dev Recipient:   ", deployer);
        console.log("Dev Fee BPS:              90 (0.90%)");
        console.log("Miner Reward BPS:         9410 (94.10%)");
        console.log("--------------------------------------------------");
    }
}
