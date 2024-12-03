// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/IPyth.sol";
import "./interfaces/PythStructs.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Oracle is Ownable {
    address public pythAddress;
    mapping(string => bytes32) public getID;
    
    struct OraclePrice {
        // Price
        uint256 price;
        // Confidence interval around the price
        uint256 publishTime;
    }

    constructor(address _pythAddress, address initialOwner) Ownable(initialOwner) {
        pythAddress = _pythAddress;
    }

    /**
     * @notice Sets a new Pyth address (only owner can do this)
     * @param _pythAddress The address of the Pyth contract
     */
    function setPythAddress(address _pythAddress) external onlyOwner {
        pythAddress = _pythAddress;
    }

    /**
     * @notice Adds a symbol and its associated ID to the getID mapping if the price feed exists.
     * @param _symbol Symbol of the asset.
     * @param _id The unique ID associated with the asset in the oracle.
     */
    function addSymbol(
        string memory _symbol,
        bytes32 _id
    ) 
        external onlyOwner
    {
        // Check if the symbol already exists in the mapping
        require(getID[_symbol] == bytes32(0), "Symbol already exists");

        // Check if the price feed exists by calling getPrice
        try IPyth(pythAddress).getPriceNoOlderThan(_id, 2400) {
            // If successful, add to mapping
            getID[_symbol] = _id;
        } catch {
            revert("Price feed does not exist");
        }
    }


    /**
     * @notice A method to get a current price from an oracle
     * @param _symbol Symbol of the asset from which to get a price.
     */
    function getPrice(
        string memory _symbol
    ) 
        external view returns (OraclePrice memory oracleResult) 
    {
        bytes32 id = getID[_symbol];
        PythStructs.Price memory priceData = IPyth(pythAddress).getPriceNoOlderThan(id,2400);
        oracleResult.publishTime = priceData.publishTime;
        // Ensure the price is positive
        require(priceData.price >= 0, "Negative price data");

        uint256 factor;
        if (priceData.expo >= 0) {
            // expo is positive, convert to uint256
            factor = 10 ** uint256(int256(priceData.expo));
            oracleResult.price = uint256(int256(priceData.price)) * (10**3) * factor;
        } else {
            // expo is negative, invert and divide
            factor = 10 ** uint256(int256(-priceData.expo));
            oracleResult.price = uint256(int256(priceData.price)) * (10**3) / factor;
        }

        return oracleResult;
    }
}
