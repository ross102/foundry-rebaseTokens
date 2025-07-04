// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC20 } from "@openzepplin/contracts/token/ERC20";

/**
 * @title - Rebase token contract
 * @author - Ifeanyi 
 * @notice - Cross chain rebase token that incentives users to deposit into a vault
 * @notice - The interest rate in the smart contract can only decrease
 * @notice - Each user will have their own interest rate
 */

contract RebaseToken is ERC20 {
    // errors
    error RebaseToken__InteresRateCanOnlyDecrease();
    
    // state variables
    uint256 private s_interestRate = 5e10;
    
    mapping(address user => uint256 interestRate) private s_userInterestRate;
    mapping(address user => uint256 time) private s_userLastUpdatedTimeStamp;

    
    //events
    event interestRateSet(uint256 newInterestRate)


    constructor() ERC20("Rebase Token", "RBT") {
    }

   /**
    * @notice - set the new interest rate to set
    * @param - _newInterestRate: The new interest rate to set  
    * @dev - The interest rate can only decrease
    */
   function setInterestRate(uint256 _newInterestRate) external {
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

    function mintAccruedInterest(address _user) internal {
      // 1)check the current balance of rebase tokens that have been 
        //minted to the user -> principalBalance
        //2) calculate their current balance including any interest -> balanceOf
        // calculate the nmber of rebase tokens that need to be minted (2) - (1)
        // call miint to mint the tokens
        // set the users last updated timestamp
    }

    function mint(address _to, uint256 amount) external {
         setUsersInterestRate(_to)
        _mint(_to, amount)
    }
     
    /**
     * @notice - gets the interest rate for that user
     * @param - _user : user to get the interest rate for
     * 
     */
    function getUserInterstRate(address _user) external view returns (uint256) {
         return userInterestRate[_user];
    }


}