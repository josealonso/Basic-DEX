//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

contract Exchange is ERC20 {
    ERC20 compluLPToken;
    // ERC20 compluToken;

    address public compluTokenAddress;

    // Exchange is inheriting ERC20, because our exchange would keep track of Complu LP tokens
    constructor(address _compluToken) ERC20("Complu LP Token", "CPLP") {
        require(_compluToken != address(0), "Token address passed is null");
        compluTokenAddress = _compluToken;
        // compluLPToken = new ERC20(_name, _symbol);
        // compluLPToken.name = _name;
        // compluLPToken.symbol = _symbol;
    }

    /**
     * @dev Returns the amount of `Complu Tokens` held by the contract
     */
    function getReserve() public view returns (uint256) {
        return ERC20(compluTokenAddress).balanceOf(address(this));
    }

    /**
     * @dev Adds liquidity to the exchange
     */
    function addLiquidity(uint256 _amount) public payable returns (uint256) {
        uint256 liquidity;
        uint256 ethBalance = address(this).balance;
        uint256 compluTokenReserve = getReserve();
        ERC20 compluToken = ERC20(compluTokenAddress);
        /*
        If the reserve is empty, intake any user supplied value for
        `Ether` and `Complu` tokens because there is no ratio currently
        */
        if (compluTokenReserve == 0) {
            compluToken.transferFrom(msg.sender, address(this), _amount);
            // Take the current ethBalance and mint `ethBalance` amount of LP tokens to the user.
            // `liquidity` provided is equal to `ethBalance` because this is the first time user
            // is adding `Eth` to the contract, so whatever `Eth` contract has is equal to the one supplied
            // by the user in the current `addLiquidity` call
            // `liquidity` tokens that need to be minted to the user on `addLiquidity` call should always be proportional
            // to the Eth specified by the user
            liquidity = ethBalance;
            _mint(msg.sender, liquidity);
        } else {
            /*
            If the reserve is not empty, intake any user supplied value for
            `Ether` and determine according to the ratio how many `Complu` tokens
            need to be supplied to prevent any large price impacts because of the additional
            liquidity
            */
            // EthReserve should be the current ethBalance subtracted by the value of ether sent by the user
            // in the current `addLiquidity` call
            uint256 ethReserve = ethBalance - msg.value;
            // Ratio should always be maintained so that there are no major price impacts when adding liquidity
            // Ratio here is -> (compluTokenAmount user can add/compluTokenReserve in the contract) = (Eth Sent by the user/Eth Reserve in the contract);
            // So doing some maths, (compluTokenAmount user can add) = (Eth Sent by the user * compluTokenReserve /Eth Reserve);
            uint256 compluTokenAmount = (msg.value * compluTokenReserve) /
                ethReserve;
            require(
                _amount >= compluTokenAmount,
                "incorrect ratio of tokens provided"
            );

            compluToken.transferFrom(
                msg.sender,
                address(this),
                compluTokenAmount
            );
            // The amount of LP tokens that would be sent to the user should be proportional to the liquidity of
            // ether added by the user
            // Ratio here to be maintained is ->
            // (LP tokens to be sent to the user (liquidity)/ totalSupply of LP tokens in contract) = (Eth sent by the user)/(Eth reserve in the contract)
            // by some maths -> liquidity =  (totalSupply of LP tokens in contract * (Eth sent by the user))/(Eth reserve in the contract)
            liquidity = (totalSupply() * msg.value) / ethReserve;
            _mint(msg.sender, liquidity);
        }
        return liquidity;
    }

    /**
     * @dev Returns the amount Eth/Complu tokens that would be returned to the user
     * in the swap
     */
    function removeLiquidity(uint256 _amount)
        public
        returns (uint256, uint256)
    {
        require(_amount > 0, "_amount should be greater than zero");
        uint256 ethReserve = address(this).balance;
        uint256 _totalSupply = totalSupply();
        // The amount of Eth that would be sent back to the user is based
        // on a ratio
        // Ratio is -> (Eth sent back to the user) / (current Eth reserve)
        // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // Then by some maths -> (Eth sent back to the user)
        // = (current Eth reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint256 ethAmount = (ethReserve * _amount) / _totalSupply;
        // The amount of Complu token that would be sent back to the user is based
        // on a ratio
        // Ratio is -> (Complu sent back to the user) / (current Complu token reserve)
        // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // Then by some maths -> (Complu sent back to the user)
        // = (current Complu token reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint256 compluTokenAmount = (getReserve() * _amount) / _totalSupply;
        // Burn the sent LP tokens from the user's wallet because they are already sent to
        // remove liquidity
        _burn(msg.sender, _amount);
        // Transfer `ethAmount` of Eth from user's wallet to the contract
        payable(msg.sender).transfer(ethAmount);
        // Transfer `compluTokenAmount` of Complu tokens from the user's wallet to the contract
        ERC20(compluTokenAddress).transfer(msg.sender, compluTokenAmount);
        return (ethAmount, compluTokenAmount);
    }
}
