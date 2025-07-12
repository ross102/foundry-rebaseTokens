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
   address alice = makeAddr("alice");
    uint256 public SEND_VALUE = 1e5;


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
       
        //  bytes[] memory  remotePoolAddressesBytesArray = new bytes[](1);
        //  remotePoolAddressesBytesArray[0] = abi.encode(remotePoolAddress); // remove

        bytes memory encodedRemotePoolAddress = abi.encode(remotePoolAddress); // nex fix
        
        chains[0] = TokenPool.ChainUpdate({
        remoteChainSelector: remoteChainSelector,
        allowed: true,
        remotePoolAddress: encodedRemotePoolAddress, // ABI-encode the array of bytes
        remoteTokenAddress: abi.encode(remoteTokenAddress),
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

      function bridgeTokens(
        uint256 amountToBridge,
        uint256 localFork,
        uint256 remoteFork,
        Register.NetworkDetails memory localNetworkDetails,
        Register.NetworkDetails memory remoteNetworkDetails,
        RebaseToken localToken,
        RebaseToken remoteToken
    ) public {
        // Create the message to send tokens cross-chain
        vm.selectFork(localFork);
        vm.startPrank(alice);
        Client.EVMTokenAmount[] memory tokenToSendDetails = new Client.EVMTokenAmount[](1);
        Client.EVMTokenAmount memory tokenAmount =
            Client.EVMTokenAmount({token: address(localToken), amount: amountToBridge});
        tokenToSendDetails[0] = tokenAmount;
        // Approve the router to burn tokens on users behalf
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress, amountToBridge);

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(alice), // we need to encode the address to bytes
            data: "", // We don't need any data for this example
            tokenAmounts: tokenToSendDetails, // this needs to be of type EVMTokenAmount[] as you could send multiple tokens
            extraArgs: "", // We don't need any extra args for this example
            feeToken: localNetworkDetails.linkAddress // The token used to pay for the fee
        });
        // Get and approve the fees
        vm.stopPrank();
        // Give the user the fee amount of LINK
        ccipLocalSimulatorFork.requestLinkFromFaucet(
            alice, IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        );
        vm.startPrank(alice);
        IERC20(localNetworkDetails.linkAddress).approve(
            localNetworkDetails.routerAddress,
            IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector, message)
        ); // Approve the fee
        // log the values before bridging
        uint256 balanceBeforeBridge = IERC20(address(localToken)).balanceOf(alice);
        console.log("Local balance before bridge: %d", balanceBeforeBridge);

        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector, message); // Send the message
        uint256 sourceBalanceAfterBridge = IERC20(address(localToken)).balanceOf(alice);
        console.log("Local balance after bridge: %d", sourceBalanceAfterBridge);
        assertEq(sourceBalanceAfterBridge, balanceBeforeBridge - amountToBridge);
        vm.stopPrank();

        vm.selectFork(remoteFork);
        // Pretend it takes 15 minutes to bridge the tokens
        vm.warp(block.timestamp + 900);
        // get initial balance on Arbitrum
        uint256 initialArbBalance = IERC20(address(remoteToken)).balanceOf(alice);
        console.log("Remote balance before bridge: %d", initialArbBalance);
         vm.selectFork(localFork); // in the latest version of chainlink-local
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        console.log("Remote user interest rate: %d", remoteToken.getUserInterestRate(alice));
        uint256 destBalance = IERC20(address(remoteToken)).balanceOf(alice);
        console.log("Remote balance after bridge: %d", destBalance);
        assertEq(destBalance, initialArbBalance + amountToBridge);
    }

     function testBridgeAllTokensBack() public {

         configureTokenPool(sepoliaFork, address(sourcePool), address(destPool), address(destRebaseToken), 
         arbSepoliaNetworkDetails.chainSelector);
         configureTokenPool(arbSepoliaFork, address(destPool),  address(sourcePool), address(sourceRebaseToken), 
         sepoliaNetworkDetails.chainSelector);
      
        vm.selectFork(sepoliaFork);
        // Pretend a user is interacting with the protocol
        vm.deal(alice, SEND_VALUE);
        vm.startPrank(alice);
        // Deposit to the vault and receive tokens
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        // bridge the tokens
        console.log("Bridging %d tokens", SEND_VALUE);
        uint256 startBalance = IERC20(address(sourceRebaseToken)).balanceOf(alice);
        assertEq(startBalance, SEND_VALUE);
        vm.stopPrank();
        // bridge ALL TOKENS to the destination chain
        bridgeTokens(
            SEND_VALUE,
            sepoliaFork,
            arbSepoliaFork,
            sepoliaNetworkDetails,
            arbSepoliaNetworkDetails,
            sourceRebaseToken,
            destRebaseToken
        );
        // bridge back ALL TOKENS to the source chain after 1 hour
        vm.selectFork(arbSepoliaFork);
        console.log("User Balance Before Warp: %d", destRebaseToken.balanceOf(alice));
        vm.warp(block.timestamp + 3600);
        console.log("User Balance After Warp: %d", destRebaseToken.balanceOf(alice));
        uint256 destBalance = IERC20(address(destRebaseToken)).balanceOf(alice);
        console.log("Amount bridging back %d tokens ", destBalance);
        bridgeTokens(
            destBalance,
            arbSepoliaFork,
            sepoliaFork,
            arbSepoliaNetworkDetails,
            sepoliaNetworkDetails,
            destRebaseToken,
            sourceRebaseToken
        );
    }

}