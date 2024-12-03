// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//pragma experimental ABIEncoderV2;
//import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./VotingEscrow.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";




contract Upgrader is Initializable{
	VotingEscrow public votingEscrow;
	address public proxyAdminAddress;
	uint256 public numberOfUpgradeVotes;
	address[] public upgradeVoteAddresses;
	mapping (string => bool) public isValidContract;
	mapping (string => address payable) public contractAddresses;
	

    struct upgradeVote{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}

	struct upgradeVotes {
    	uint256 voteID;
        uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        string contractToUpgrade;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    }

	mapping(address => upgradeVotes) public getUpgradeVotes;

	mapping (uint256 => mapping (address => bool)) public hasVoted;

	
	//NEW
	uint256 public lastVoteID;
	mapping (address => uint256) public lastUpgradeVoteIDByImplementationAddress;
	

	mapping (uint256 => upgradeVoteDetails) public allUpgradeVotesByID;
	
	struct upgradeVoteDetails{
		bool voteResult;
		bool open;
		uint256 endingTime;
	}
	

	function initialize(
		//VotingEscrow _votingEscrow,
		address _proxyAdminAddress,	
		address payable _assetFactoryAddress,		
		address payable _DAOAddress,
		address payable _votingEscrowAddress,
		address payable _rewardsMachineAddress
		) 
		public initializer 
		{
        votingEscrow = VotingEscrow(_votingEscrowAddress);
        proxyAdminAddress = _proxyAdminAddress;
		lastVoteID = 1;
		isValidContract['AssetFactory'] = true;
		isValidContract['DAO'] = true;
		isValidContract['Upgrader'] = true;
		isValidContract['VotingEscrow'] = true;
		isValidContract['RewardsMachine'] = true;

		contractAddresses['AssetFactory'] = _assetFactoryAddress;
		contractAddresses['DAO'] = _DAOAddress;
		contractAddresses['VotingEscrow'] = _votingEscrowAddress;
		contractAddresses['RewardsMachine'] = _rewardsMachineAddress;
		contractAddresses['Upgrader'] = payable(address(this));
    }

	
	event upgradeVoteInitiated(
		address _newImplementationAddress,
		string _contractToUpgrade
	);

	event upgradeVoteClosed(
		address _newImplementationAddress,
		string _contractToUpgrade,
		bool success
	);

	
	/**
    * @notice A method initiates a new voting process if a certain address gets funding.
    * @param _newImplementationAddress Address that is supposed as the new implementation
    *        _contractToUpgrade Contract that is updated
    */
    function initiateUpgradeVote(
		address _newImplementationAddress,
		string calldata _contractToUpgrade
		)
		external 
		{
		(uint256 voteNumber,) = votingEscrow.lockedBalances(msg.sender);	
		require (voteNumber > 100000*(10**18),'INSUFFICIENT_veToken');
		require (getUpgradeVotes[_newImplementationAddress].open == false,'VOTE_OPEN');   //check if the voting process is open
		
		require (isValidContract[_contractToUpgrade],'UNKNOWN_CONTRACT');
		//require (Address.isContract(_newImplementationAddress),"ADDRESS_NO_CONTRACT");
		
		if (getUpgradeVotes[_newImplementationAddress].exists != true)
			{
			numberOfUpgradeVotes +=1;
    		upgradeVoteAddresses.push(_newImplementationAddress);
			}
		//delete (getGrantVotes[_receiver].individualVotes);
		
		
		getUpgradeVotes[_newImplementationAddress].startingTime = (block.timestamp);
    	getUpgradeVotes[_newImplementationAddress].endingTime = block.timestamp + 7 days;
    	getUpgradeVotes[_newImplementationAddress].yesVotes = 0;
    	getUpgradeVotes[_newImplementationAddress].noVotes = 0;
    	getUpgradeVotes[_newImplementationAddress].open = true;
    	getUpgradeVotes[_newImplementationAddress].exists = true;   	
    	getUpgradeVotes[_newImplementationAddress].contractToUpgrade = _contractToUpgrade;
    	emit upgradeVoteInitiated(_newImplementationAddress, _contractToUpgrade);
    	//New
    	getUpgradeVotes[_newImplementationAddress].voteID = lastVoteID +1;
    	lastUpgradeVoteIDByImplementationAddress[_newImplementationAddress] = lastVoteID + 1;
    	allUpgradeVotesByID[lastVoteID +1].open = true;
    	lastVoteID = lastVoteID + 1;
    	
    }



	/**
    * @notice A method that votes if a suggest grant will be given or not
    * @param _newImplementationAddress Address that is supposed as the new implementation
    *.       _vote     True or False aka Yes or No
    */
    function voteUpgradeVote (
		address _newImplementationAddress, 
		bool _vote
		)
		external
		{
		(uint256 voteNumber, uint256 lockedUntil) = votingEscrow.lockedBalances(msg.sender);
		require(lockedUntil > getUpgradeVotes[_newImplementationAddress].endingTime,'LOCK_TOO_SHORT');
		uint256 voteID = lastUpgradeVoteIDByImplementationAddress[_newImplementationAddress];
		require(hasVoted[voteID][msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		hasVoted[voteID][msg.sender] = true;

		require(getUpgradeVotes[_newImplementationAddress].exists,'UNKNOWN'); //checks if the grant request exists)
		require(getUpgradeVotes[_newImplementationAddress].open,'NOT_OPEN'); //checks is the vote is open)
		require(getUpgradeVotes[_newImplementationAddress].endingTime >= block.timestamp, 'VOTE_ENDED'); //checks if the voting period is still open
		
		if (_vote == true) {
			getUpgradeVotes[_newImplementationAddress].yesVotes = getUpgradeVotes[_newImplementationAddress].yesVotes + voteNumber;
			
		}
		else {
			getUpgradeVotes[_newImplementationAddress].noVotes = getUpgradeVotes[_newImplementationAddress].noVotes + voteNumber;
		}
		
		getUpgradeVotes[_newImplementationAddress].voteNumber = getUpgradeVotes[_newImplementationAddress].voteNumber + 1;
	}

	/**
    * @notice A method that checks if an address has already voted in a grant Vote.
    * @param _address Address that is checked
    *        _newImplementationAddress Address that is supposed as the new implementation
    */
    function checkIfVotedUpgrade(
		address _address, 
		address _newImplementationAddress
		) 
		external
		view
		returns(bool)
		{
		uint256 voteID = lastUpgradeVoteIDByImplementationAddress[_newImplementationAddress];
		return (hasVoted[voteID][_address]);
	}

	
	/**
    * @notice A method that closes a specific upgrade voting process.
    * @param _newImplementationAddress Address that is supposed as the new implementation
    */
    function closeUpgradeVote (
		address _newImplementationAddress
		)
		external 
		{
		require(getUpgradeVotes[_newImplementationAddress].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getUpgradeVotes[_newImplementationAddress].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getUpgradeVotes[_newImplementationAddress].endingTime < block.timestamp);
		getUpgradeVotes[_newImplementationAddress].open = false;
		
		
		if (getUpgradeVotes[_newImplementationAddress].yesVotes > getUpgradeVotes[_newImplementationAddress].noVotes){
			string memory contractName = getUpgradeVotes[_newImplementationAddress].contractToUpgrade;
			address payable proxyAddress = contractAddresses[contractName];
			ProxyAdmin(proxyAdminAddress).upgradeAndCall(ITransparentUpgradeableProxy(proxyAddress),_newImplementationAddress,"");
			emit upgradeVoteClosed(_newImplementationAddress, getUpgradeVotes[_newImplementationAddress].contractToUpgrade,true);	
			// HERE COMES THE STUFF THAT IMPLEMENTS THE NEW CONTRACT

			}
		else {
			emit upgradeVoteClosed(_newImplementationAddress, getUpgradeVotes[_newImplementationAddress].contractToUpgrade,false);
			
		}
		
		
		//delete(getGrantVotes[_receiver]);
		//emit grantFundingVoteClosed(_receiver,true);		
	}

	/**
	* @notice A method that gets the details of a specific grant poposal Vote
	* @param _address Address to check
	*/
	function getUpgradeVoteDetails(
		address _address
		)
		external
		view
		returns (uint256,uint256,uint256,string memory,bool)
		{
			//uint256 startingTime = getGrantVotes[_address].startingTime;
			uint256 endingTime = getUpgradeVotes[_address].endingTime;
			uint256 yesVotes = getUpgradeVotes[_address].yesVotes;
			uint256 noVotes = getUpgradeVotes[_address].noVotes;
			//bool proposalExists = getGrantVotes[_address].exists;
			string memory contractToUpgrade = getUpgradeVotes[_address].contractToUpgrade;
			bool upgradeVoteOpen = getUpgradeVotes[_address].open;
			
			return (endingTime,yesVotes,noVotes,contractToUpgrade,upgradeVoteOpen);
		}


	
}