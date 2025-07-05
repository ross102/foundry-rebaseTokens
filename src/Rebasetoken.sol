// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzepplin/contracts/token/ERC20";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title - Rebase token contract
 * @author - Ifeanyi 
 * @notice - Cross chain rebase token that incentives users to deposit into a vault
 * @notice - The interest rate in the smart contract can only decrease
 * @notice - Each user will have their own interest rate
 */

contract RebaseToken is ERC20, Ownable, AccessControl {
    // errors
    error RebaseToken__InteresRateCanOnlyDecrease();
    
    // state variables
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");
    uint256 private constant PRECISION_FACTOR = 1e18; 
    uint256 private s_interestRate = 5e10;
    
    mapping(address user => uint256 interestRate) private s_userInterestRate;
    mapping(address user => uint256 time) private s_userLastUpdatedTimeStamp;

    
    //events
    event interestRateSet(uint256 newInterestRate)


    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender)  {
    }

      /**
    * @notice - Grant mint and burn role to the account
    * @param - _account: The account to grant mint and burn role to   
    * 
    */
    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

   /**
    * @notice - set the new interest rate to set
    * @param - _newInterestRate: The new interest rate to set  
    * @dev - The interest rate can only decrease
    */
   function setInterestRate(uint256 _newInterestRate) external onlyOwner {
       if(_newInterestRate > s_interestRate) {
         revert RebaseToken__InteresRateCanOnlyDecrease(s_interestRate, _newInterestRate)
       }
         // set the interest rate
         s_interestRate = _newInterestRate
         emit interestRateSet(_newInterestRate)
    }

    function setUsersInterestRate(address _to) external {
        s_userInterestRate[_to] = s_interestRate
    }
     
    function principalBalanceOf(address _user) external view returns(uint256) {
        return super.balanceOf(_user);
    }

    /**
     * @notice - Get the principal balance not including the interest
     * @param - _user:  The uuser address
     */
    function balanceOf(address _user) public view overrides returns(uint) {
        // get the principal balance of tokens (The number of tokens 
        // the user actually has)
        // multiple the principal balance with the interest that has accumulated
         return  super.balanceOf(_user) * calculateUserAccumulatedInterestSinceLastUpdate(_user) / PRECISION_FACTOR

    }
     /**
      * @notice - transfer tokens from one user to another
      * @param - _to : the user to receive the tokens
      * @param - _amount: the amount to transfer
      * @return - returns a boolean
      */
    function transfer(address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_to);

        if(_amount == type(uint256).max) {
            amount = balanceOf(msg.sender);
        }

        if(balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[msg.sender];
        }

       return super.transfer(_to, _amount);
    }

     /**
      * @notice - transfer tokens from one user to another
      * @param - _to : the user to receive the tokens
      * @param - _from : the user to send the tokens  
      * @param - _amount: the amount to transfer
      * @return - returns a boolean
      */
    function transferFrom(address _from, address _to, uint256 _amount) public override returns (bool) {
        _mintAccruedInterest(_from);
        _mintAccruedInterest(_to);

        if(_amount == type(uint256).max) {
            amount = balanceOf(_from);
        }

        if(balanceOf(_to) == 0) {
            s_userInterestRate[_to] = s_userInterestRate[_from];
        }

       return super.transferFrom(_from, _to, _amount);
    }

     /**
     * @notice - Calculate the interest that has accumulated since last update
     * @param - _user:  The user to calculate the interest accumulated for
     * @return - The interest that has accrued
     */
    function calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns(uint256 linearInterest) {
        // calculate the time since the last update
        // calculate the linear growth
        uint256 timeElasped = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[user] * timeElasped);

    }
    /**
     * @notice - Mint accured interest to the user since the last time they interacted with the protocol(mint, burn, transfer)
     * @param - _user: The user to mint the tokens to
     * 
     */
    function _mintAccruedInterest(address _user) internal {
      // 1)check the current balance of rebase tokens that have been 
        //minted to the user -> principalBalance
         uint256 previousPrincipalBalance = super.balanceOf(_user);
        //2) calculate their current balance including any interest -> balanceOf
         uint256 currentBalance = balanceOf(_user);
        // calculate the nmber of rebase tokens that need to be minted (2) - (1)
         uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        // call miint to mint the tokens
        // set the users last updated timestamp
         s_userLastUpdatedTimeStamp[_user] = block.timestamp;
          _mint(_user, balanceIncrease);
    }


    /**
     * Mint the user tokens when they deposit into the vault
     * @param - _to: The user to mint the tokens to
     * @param - _amount: The amount of tokens to mint
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to)
         setUsersInterestRate(_to)
        _mint(_to, _amount)
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        if(_amount == type(uint256).max) {
            _amount = balanceOf(_from)
        }
        _mintAccruedInterest(_to);
        _burn(_from, _amount);
    }

    /**
     * @notice - gets the interest rate of the smart contract
     * 
     */
    function getInterestRate() external view returns (uint256) {
         return s_interestRate;
    }
     
    /**
     * @notice - gets the interest rate for that user
     * @param - _user : user to get the interest rate for
     * 
     */
    function getUserInterestRate(address _user) external view returns (uint256) {
         return userInterestRate[_user];
    }


}