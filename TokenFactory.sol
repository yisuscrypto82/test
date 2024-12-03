// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//import "./openzeppelin/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./AssetToken.sol";



	contract TokenFactory is Ownable(msg.sender){
	//using SafeMath for uint256;

	/**
    * @notice A method that deploys a new token contract.
    * @param  _name Name of the asset
    *         _symbol Symbol of the new asset token
    *         _description Description of the new asset
    *         _upperLimit Upper limit set for this asset
    */
    function deployToken (
		string calldata _name, 
		string calldata _symbol
		)
		external 
		onlyOwner 
		returns (address)
		{
		address token = address(new AssetToken(_name,_symbol));
		return (token);
	}


	/**
    * @notice A method that adds mints new tokens. Can only be issued by the owner, which is the Asset Factory contract.
    * @param  _token Address of the token to mint
    *         _to Address that shall receive the newly minted tokens
    *         _amount Amount of new tokens to be minted (in WEI)
    */
    function mint (
		address _token,
		address _to,
		uint256 _amount
		)
		external
		onlyOwner
		{
		AssetToken(_token).mint(_to, _amount);
	}

	/**
    * @notice A method that burns tokens. Can only be issued by the owner, which is the Asset Factory contract.
    * @param  _token Address of the token to be burned
    *         _from Address from which the tokens shall be burned
    *         _amount Amount of new tokens to be minted (in WEI)
    */
    function burn (
		address _token,
		address _from,
		uint256 _amount
		)
		external
		onlyOwner
		{
		AssetToken(_token).burn(_from, _amount);
	}

}