// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AssetToken.sol";
import "./Oracle.sol";
import "./TokenFactory.sol";
//import "./issuaaLibrary.sol";
import "./interfaces/IYieldFarm.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";





contract AssetFactory is Initializable {
	bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
	uint256 public assetNumber;
	address public USDCaddress;
    address public tokenFactoryAddress;
    address public feeTo;
	address public yieldFarmAddress;
	address public oracleAddress;
    string[] public assets;
    mapping(string => Asset) public getAsset;
	bool public isPaused;
    address pauseAccount;

	struct Asset {
    	address Token1; 
    	address Token2; 
    	uint256 upperLimit;
    	uint256 endOfLifeValue;
    	uint256 expiryTime;
    	bool frozen;
        bool expired;
    	bool exists;
    }
	
    
    // Modifier to check that the caller is the owner of
    // the contract.
    modifier notPaused() {
        require(isPaused == false, "CONTRACT_PAUSED");
        _;
    }

    function pauseContract(
        )
        public
        {
        require(msg.sender == pauseAccount,"NOT_PAUSEACCOUNT");
        isPaused = true;
    }

    function unpauseContract(
        )
        public
        {
        require(msg.sender == pauseAccount,"NOT_PAUSEACCOUNT");
        isPaused = false;
    }

	function initialize(
		address _oracleAddress,
		address _tokenFactoryAddress,
		address _USDCAddress,
        address _pauseAccount,
		address _yieldFarmAddress,
		address _feeTo
		 
		) 
		public initializer 
		{
			oracleAddress = _oracleAddress;
			tokenFactoryAddress = _tokenFactoryAddress;
			USDCaddress = _USDCAddress;
			pauseAccount = _pauseAccount;
			yieldFarmAddress = _yieldFarmAddress;
			feeTo = _feeTo;
    }

	event Freeze(
        string _symbol
    );

    event EndOfLiveValueSet (
    	string _symbol, 
    	uint256 _value
    );

    event Mint (
		string _symbol, 
		uint256 _amount
	) ;

    event Burn (
		string _symbol, 
		uint256 _amount
	); 

    event BurnExpired (
		string _symbol, 
		uint256 _amount1,
		uint256 _amount2
	); 

	event NewAsset (
		string _symbol, 
		uint256 _upperLimit
	);

	

	/**
	* @notice A method to safely transfer ERV20 tokens.
	* @param _token Address of the token.
		_from Address from which the token will be transfered.
		_to Address to which the tokens will be transfered
		_value Amount of tokens to be sent.	
	*/
	function _transferFrom(
		address _token, 
		address _from, 
		address _to, 
		uint256 _value
		) 
		private 
		{
        (bool success, bytes memory data) = _token.call(abi.encodeWithSelector(SELECTOR, _from, _to, _value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'FAILED');
    }

	

	/**
	* @notice A method to define ad create a new Asset.
	* @param _symbol Symbol of the new Asset.
		_description Short description of the asset
		_upperLimit Upper limit of the assets, that defines when the asset is frozen.	
	*/
	function createAssets (
		string calldata _symbol
		) 
		external
		notPaused 
		{
		require (getAsset[_symbol].exists == false,'EXISTS'); assets.push(_symbol);
		Oracle.OraclePrice memory oracleData = Oracle(oracleAddress).getPrice(_symbol);
		require(block.timestamp - oracleData.publishTime < 1 hours,'ORACLE DATA TOO OLD');
		require(block.timestamp > oracleData.publishTime,'ORACLE DATA INVALID');
		assetNumber = assetNumber + 1;
		getAsset[_symbol].Token1 = TokenFactory(tokenFactoryAddress).deployToken(string(abi.encodePacked("TWIN ASSET TOKEN - ",_symbol)),string(_symbol));
		getAsset[_symbol].Token2 = TokenFactory(tokenFactoryAddress).deployToken(string(abi.encodePacked("TWIN ASSET TOKEN - i",_symbol)),string(abi.encodePacked("i",_symbol)));
		getAsset[_symbol].upperLimit = oracleData.price * 2;
		getAsset[_symbol].expiryTime = block.timestamp + 365 days;
		getAsset[_symbol].exists = true;
		emit NewAsset ( _symbol, oracleData.price * 2);
	}





	/**
	* @notice A method that checks if a specific asset does already exist.
	* @param _symbol Symbol of the asset to check.
	* @return bool Returns true if the asset exists and false if not.
	*/
	function assetExists (
		string calldata _symbol
		)
		external 
		view 
		returns(bool)
		{
		return(getAsset[_symbol].exists);
	}

	/**
	* @notice A method that checks if a specific asset is frozen.
	* @param _symbol Symbol of the asset to check.
	* @return bool Returns true if the asset is frozen or not.
	*/
	function assetFrozen (
		string calldata _symbol
		)
		external 
		view 
		returns(bool)
		{
		return(getAsset[_symbol].frozen);
	}
	
	/**
	* @notice A method that checks if a specific asset is marked as expired.
	* @param _symbol Symbol of the asset to check.
	* @return bool Returns true if the asset is expired or not.
	*/
	function assetExpired (
		string calldata _symbol
		)
		external 
		view 
		returns(bool)
		{
		return(getAsset[_symbol].expired);
	}

	/**
	* @notice A message that checks the expiry time of an asset.
	* @param _symbol Symbol of the asset to check.
	* @return uint256 Returns the expiry time as a timestamp.
	*/
	function getExpiryTime(
		string calldata _symbol
		)
		external 
		view 
		returns(uint256)
		{
		return (getAsset[_symbol].expiryTime);
	}


	/**
	* @notice A message that checks the upper limit an asset.
	* @param _symbol Symbol of the asset to check.
	* @return uint256 Returns the upper limit.
	*/
	function getUpperLimit(
		string calldata _symbol
		)
		external 
		view 
		returns(uint256)
		{
		return (getAsset[_symbol].upperLimit);
	}

	/**
	* @notice A message that checks the expiry price of an asset.
	* @param _symbol Symbol of the asset to check.
	* @return uint256 Returns the expiry price.
	*/
	function getExpiryPrice(
		string calldata _symbol
		) 
		external 
		view 
		returns(uint256)
		{
		return (getAsset[_symbol].endOfLifeValue);
	}

	/**
	* @notice A message that checks the token addresses for an asset symbol.
	* @param _symbol Symbol of the asset to check.
	* @return address, address Returns the long und short token addresses.
	*/
	function getTokenAddresses(
		string calldata _symbol
		) 
		external 
		view 
		returns(address,address)
		{
		return (getAsset[_symbol].Token1, getAsset[_symbol].Token2);
	}

	/**
	* @notice A message that mints a specific asset. The caller will get both long and short
	*         assets and will pay the upper limit in USD stable coins as a price.
	* @param _symbol Symbol of the asset to mint.
	*/
	function mintAssets (
		string calldata _symbol, 
		uint256 _amount
		) 
		external
		notPaused 
		{
		require (getAsset[_symbol].frozen == false && getAsset[_symbol].expiryTime > block.timestamp,'INVALID'); 
		IERC20(USDCaddress).transferFrom(msg.sender,address(this),_amount);
		IERC20(USDCaddress).approve(yieldFarmAddress,_amount);
		IYieldFarm(yieldFarmAddress).supply(_amount);
		uint256 USDDecimals = ERC20(USDCaddress).decimals();
		uint256 tokenAmount = _amount * (10**(18-USDDecimals))* 1000 / getAsset[_symbol].upperLimit;
		TokenFactory(tokenFactoryAddress).mint(getAsset[_symbol].Token1, msg.sender, tokenAmount);
		TokenFactory(tokenFactoryAddress).mint(getAsset[_symbol].Token2, msg.sender, tokenAmount);
		emit Mint(_symbol, _amount);
	}

	/**
	* @notice A message that burns a specific asset to get USD stable coins in return.
	* @param _symbol Symbol of the asset to burn.
	*        _amount Amount of long and short tokens to be burned.
	*/
	function burnAssets (
		string calldata _symbol,
		uint256 _amount
		) 
		external 
		notPaused
		{
		require(getAsset[_symbol].expired == false,'EXPIRED');
		uint256 USDDecimals = ERC20(USDCaddress).decimals();
		uint256 amountOut = _amount * getAsset[_symbol].upperLimit / (10**(18-USDDecimals)) / 1000;
		IYieldFarm(yieldFarmAddress).withdraw(amountOut);
		if (getAsset[_symbol].frozen) {
			IERC20(USDCaddress).transfer(msg.sender,amountOut);
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token1, msg.sender, _amount);
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token2, msg.sender, AssetToken(getAsset[_symbol].Token2).balanceOf(msg.sender));
			//AssetToken(getAsset[_symbol].Token1).transferFrom(msg.sender, address(this), _amount);
			//AssetToken(getAsset[_symbol].Token2).transferFrom(msg.sender, address(this), AssetToken(getAsset[_symbol].Token2).balanceOf(msg.sender));
		}
		else {
			IERC20(USDCaddress).transfer(msg.sender,amountOut*98/100);
			IERC20(USDCaddress).transfer(feeTo,amountOut - (amountOut*98/100));
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token1, msg.sender, _amount);
			TokenFactory(tokenFactoryAddress).burn(getAsset[_symbol].Token2, msg.sender, _amount);
			
			//AssetToken(getAsset[_symbol].Token1).burn(msg.sender, _amount);
			//AssetToken(getAsset[_symbol].Token2).burn(msg.sender, _amount);

		}
		emit Burn (_symbol, _amount);	
	}

	/**
	* @notice A method that burns a specific expired asset to get USD stable coins in return.
	* @param _symbol Symbol of the asset to burn.
	*        _amount1 Amount of the long token to be burned.
	*        _amount2 Amount of the short token to be burned.
	*/
	function burnExpiredAssets (
		string calldata _symbol, 
		uint256 _amount1, 
		uint256 _amount2
		) 
		external
		notPaused 
		{
		require(getAsset[_symbol].expired == true,'NOT_EXPIRED');
		require(getAsset[_symbol].frozen == false,'FROZEN');
		require(getAsset[_symbol].endOfLifeValue > 0,'VOTE_NOT_CLOSED');
		
		uint256 USDDecimals = ERC20(USDCaddress).decimals();
		uint256 valueShort = getAsset[_symbol].upperLimit - getAsset[_symbol].endOfLifeValue;
		uint256 amountOut1 = _amount1 * getAsset[_symbol].endOfLifeValue / (10**(18-USDDecimals)) / 1000;
		uint256 amountOut2 = _amount2 * valueShort / (10**(18-USDDecimals)) / 1000;
		IYieldFarm(yieldFarmAddress).withdraw(amountOut1+amountOut2);
        IERC20(USDCaddress).transfer(msg.sender,amountOut1 + amountOut2);
        AssetToken(getAsset[_symbol].Token1).transferFrom(msg.sender, address(this), _amount1);
        AssetToken(getAsset[_symbol].Token2).transferFrom(msg.sender, address(this), _amount2);
        emit BurnExpired (_symbol, _amount1, _amount2);
	}

    /**
	* @notice A method that freezes a specific asset. 
	* @param _symbol Symbol of the asset to freeze.
	*/
    function freezeAsset(
    	string calldata _symbol
    	) 
    	external
		notPaused 
    	{
    	Oracle.OraclePrice memory oracleData = Oracle(oracleAddress).getPrice(_symbol);
		require(block.timestamp - oracleData.publishTime < 1 hours,'ORACLE DATA TOO OLD');
		require(block.timestamp > oracleData.publishTime,'ORACLE DATA INVALID');
    	require(oracleData.price > getAsset[_symbol].upperLimit);
    	require(block.timestamp < getAsset[_symbol].expiryTime);
		getAsset[_symbol].frozen = true;
    	emit Freeze (_symbol);
    }

    /**
	* @notice A method that sets the expiry value of a specific asset. 
	* @param _symbol Symbol of the asset to freeze.
	*        
	*/
	function setEndOfLifeValue(
    	string calldata _symbol
    	) 
    	external
		notPaused 
    	{
		uint256 endOfLifeValue;
    	Oracle.OraclePrice memory oracleData = Oracle(oracleAddress).getPrice(_symbol);
		require(block.timestamp - oracleData.publishTime < 1 hours,'ORACLE DATA TOO OLD');
		require(block.timestamp > oracleData.publishTime,'ORACLE DATA INVALID');
    	require(block.timestamp > getAsset[_symbol].expiryTime);
		if (oracleData.price > getAsset[_symbol].upperLimit){
			endOfLifeValue = getAsset[_symbol].upperLimit;		
		} else {
			endOfLifeValue = oracleData.price;
		}
    	getAsset[_symbol].endOfLifeValue = endOfLifeValue;
    	getAsset[_symbol].expired = true;
    	emit EndOfLiveValueSet (_symbol,endOfLifeValue);
    }

}