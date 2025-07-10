// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console, Test} from "forge-std/Test.sol";

import {CCIPLocalSimulatorFork, Register} from "@chainlink-local/src/ccip/CCIPLocalSimulatorFork.sol";
import {TokenPool} from "@ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RegistryModuleOwnerCustom} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";
import {TokenAdminRegistry} from "@ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {RateLimiter} from "@ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IERC20} from "@ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {IRouterClient} from "@ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";

import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";

import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";

import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";


contract CrossChain is Test {

   address[] public allowlist = new address[](0);

   uint256 sepoliaFork;
   uint256 arbSepoliaFork;

   CCIPLocalSimulatorFork public ccipLocalSimulatorFork;
   
   address public owner = makeAddr("owner");

    RebaseToken destRebaseToken;
    RebaseToken sourceRebaseToken;

    Vault vault;

    RebaseTokenPool destPool;
    RebaseTokenPool sourcePool;

    TokenAdminRegistry tokenAdminRegistrySepolia;
    TokenAdminRegistry tokenAdminRegistryarbSepolia;

    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbSepoliaNetworkDetails;

    RegistryModuleOwnerCustom registryModuleOwnerCustomSepolia;
    RegistryModuleOwnerCustom registryModuleOwnerCustomarbSepolia;


   function setUp() external {
   
        sepoliaFork = vm.createSelectFork("eth");
        arbSepoliaFork = vm.createFork("arb");

        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();
        vm.makePersistent(address(ccipLocalSimulatorFork));
         //  deploy on source chain(sepolia)
        vm.startPrank(owner);
         
        sourceRebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sourceRebaseToken)));
        vm.deal(address(vault), 1e18);
        
        
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);
        
        sourcePool = new RebaseTokenPool(
            IERC20(address(sourceRebaseToken)),
            allowlist,
            sepoliaNetworkDetails.rmnProxyAddress,
            sepoliaNetworkDetails.routerAddress
        );

        sourceRebaseToken.grantMintAndBurnRole(address(sourcePool));
        sourceRebaseToken.grantMintAndBurnRole(address(vault));
        
         // Claim role on Sepolia
        registryModuleOwnerCustomSepolia =
            RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustomSepolia.registerAdminViaOwner(address(sourceRebaseToken));
        // Accept role on Sepolia
        tokenAdminRegistrySepolia = TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistrySepolia.acceptAdminRole(address(sourceRebaseToken));
        // Link token to pool in the token admin registry on Sepolia
        tokenAdminRegistrySepolia.setPool(address(sourceRebaseToken), address(sourcePool));
       
        
        vm.stopPrank();
         // select destination chain(arbitrum) and deploy
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);

        destRebaseToken = new RebaseToken();

        arbSepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);  

          destPool = new RebaseTokenPool(
            IERC20(address(destRebaseToken)),
            allowlist,
            arbSepoliaNetworkDetails.rmnProxyAddress,
            arbSepoliaNetworkDetails.routerAddress
        );
        
        destRebaseToken.grantMintAndBurnRole(address(destPool));

        // Claim role on Arbitrum
        registryModuleOwnerCustomarbSepolia =
            RegistryModuleOwnerCustom(arbSepoliaNetworkDetails.registryModuleOwnerCustomAddress);
        registryModuleOwnerCustomarbSepolia.registerAdminViaOwner(address(destRebaseToken));
        // Accept role on Arbitrum
        tokenAdminRegistryarbSepolia = TokenAdminRegistry(arbSepoliaNetworkDetails.tokenAdminRegistryAddress);
        tokenAdminRegistryarbSepolia.acceptAdminRole(address(destRebaseToken));
        // Link token to pool in the token admin registry on Arbitrum
        tokenAdminRegistryarbSepolia.setPool(address(destRebaseToken), address(destPool));

         configureTokenPool(sepoliaFork, address(sourcePool), address(destPool), address(destRebaseToken), arbSepoliaNetworkDetails.chainSelector);
         configureTokenPool(arbSepoliaFork, address(destPool),  address(sourcePool), address(sourceRebaseToken), sepoliaNetworkDetails.chainSelector);

         vm.stopPrank();
   }

  
    function configureTokenPool(
        uint256 fork,
        address localPool,
        address remotePoolAddress,
        address remoteTokenAddress,
        uint64 remoteChainSelector
    ) public {
        vm.selectFork(fork);
               
        TokenPool.ChainUpdate[] memory chains = new TokenPool.ChainUpdate[](1);
       
         bytes[] memory  remotePoolAddressesBytesArray = new bytes[](1);
         remotePoolAddressesBytesArray[0] = abi.encode(remotePoolAddress);
        
        chains[0] = TokenPool.ChainUpdate({
        remoteChainSelector: remoteChainSelector,
        allowed: true,
        remotePoolAddress: abi.encode(remotePoolAddressesBytesArray), // ABI-encode the array of bytes
        remoteTokenAddress: abi.encode(remoteTokenAddress),
        // For this example, rate limits are disabled.
        outboundRateLimiterConfig: RateLimiter.Config({
            isEnabled: false,
            capacity: 0,
            rate: 0
        }),
        inboundRateLimiterConfig: RateLimiter.Config({
            isEnabled: false,
            capacity: 0,
            rate: 0
        })
        });
         //uint64[] memory remoteChainSelectorsToRemove = new uint64[](0);
         vm.prank(owner); 

        TokenPool(localPool).applyChainUpdates(chains);
        
    }

    
}