// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
//pragma experimental ABIEncoderV2;
//import "@openzeppelin/contracts/access/Ownable.sol";
import "./VotingEscrow.sol";
import "./GovernanceToken.sol";
import "./AssetFactory.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";



contract DAO is Initializable{
	VotingEscrow public votingEscrow;
	AssetFactory public assetFactory;
	GovernanceToken public governanceToken;
	uint256 public numberOfGrantVotes;
	address[] public grantVoteAddresses;
	uint256 DAOVolume;
	uint256 public votingDuration;

    struct grantFundingVote{
		address votingAddress;
		bool voted;
		uint256 yesVotes;
		uint256 noVotes;
	}

	struct grantFundingVotes {
    	uint256 voteID;
        uint256 startingTime;
        uint256 endingTime;
        uint256 yesVotes;
        uint256 noVotes;
        uint256 amount;
        string description;
    	bool open;
    	bool exists;
    	mapping (address => bool) hasvoted;
    	uint256 voteNumber;
    }

	mapping(address => grantFundingVotes) public getGrantVotes;
	
    mapping (uint256 => mapping (address => bool)) public hasVoted;

	
	uint256 public lastVoteID;
	mapping (address => uint256) public lastGrantVoteIDByReceiver;

	mapping (uint256 => grantVoteDetails) public allGrantVotesByID;

	struct grantVoteDetails{
		bool voteResult;
		bool open;
		uint256 endingTime;
	}
	
    bool public isPaused;
    address pauseAccount;
    
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
		VotingEscrow _votingEscrow, 
		AssetFactory _assetFactory,
		GovernanceToken _governanceToken,
		uint256 _DAOVolume,
		uint256 _lastVoteID,
        address _pauseAccount,
		uint256 _votingDuration 
		) 
		public initializer 
		{
        votingEscrow = _votingEscrow;
		assetFactory = _assetFactory;
		governanceToken = _governanceToken;
		DAOVolume = _DAOVolume * 1e18;
		lastVoteID = _lastVoteID;
        pauseAccount = _pauseAccount;
		votingDuration = _votingDuration;
    }

	
	event grantFundingVoteInitiated(
		address _receiver,
		uint256 _amount,
		string _description
	);

	event grantFundingVoteClosed(
		address _receiver,
		bool success
	);



	

	
	
	
	/**
    * @notice A method initiates a new voting process if a certain address gets funding.
    * @param _receiver Address that will receive the grant
    *        _amount   Amount of grant in WEI
    *        _description Description for what you request funding
    */
    function initiateGrantFundingVote(
		address _receiver,
		uint256 _amount,
		string calldata _description
		)
		external 
		notPaused
		{
		uint256 voteNumber = votingEscrow.balanceOf(msg.sender);
		require (voteNumber > 100000*(10**18),'INSUFFICIENT_ve_BALANCE');
		require (getGrantVotes[_receiver].open == false,'VOTE_OPEN');   //check if the voting process is open
		require (_amount < (100000 * (10**18)),'AMOUNT_TOO_HIGH');
		if (getGrantVotes[_receiver].exists != true)
			{
			numberOfGrantVotes +=1;
    		grantVoteAddresses.push(_receiver);
			}
		DAOVolume = DAOVolume - _amount;
		//delete (getGrantVotes[_receiver].individualVotes);
		
		getGrantVotes[_receiver].startingTime = (block.timestamp);
    	getGrantVotes[_receiver].endingTime = block.timestamp + votingDuration;
    	getGrantVotes[_receiver].yesVotes = 0;
    	getGrantVotes[_receiver].noVotes = 0;
    	getGrantVotes[_receiver].open = true;
    	getGrantVotes[_receiver].exists = true;
    	getGrantVotes[_receiver].amount = _amount;    	
    	getGrantVotes[_receiver].description = _description;
    	emit grantFundingVoteInitiated(_receiver, _amount, _description);
    	//New
    	getGrantVotes[_receiver].voteID = lastVoteID +1;
    	lastGrantVoteIDByReceiver[_receiver] = lastVoteID + 1;
    	allGrantVotesByID[lastVoteID +1].open = true;
    	lastVoteID = lastVoteID + 1;
    }



	/**
    * @notice A method that votes if a suggest grant will be given or not
    * @param _receiver Address that has requested a DAO grant
    *.       _vote     True or False aka Yes or No
    */
    function voteGrantFundingVote (
		address _receiver, 
		bool _vote
		)
		external
		notPaused
		{
		
		uint256 voteNumber = votingEscrow.balanceOf(msg.sender);
		uint256 voteID = lastGrantVoteIDByReceiver[_receiver];
		require(hasVoted[voteID][msg.sender] == false, 'VOTED_AlREADY');  // check if the address has voted already
		hasVoted[voteID][msg.sender] = true;

		require(getGrantVotes[_receiver].exists,'UNKNOWN'); //checks if the grant request exists)
		require(getGrantVotes[_receiver].open,'NOT_OPEN'); //checks is the vote is open)
		require(getGrantVotes[_receiver].endingTime >= block.timestamp, 'VOTE_ENDED'); //checks if the voting period is still open
		
		
		if (_vote == true) {
			getGrantVotes[_receiver].yesVotes = getGrantVotes[_receiver].yesVotes + voteNumber;
			//individualVote.yesVotes = voteNumber;

		}
		else {
			getGrantVotes[_receiver].noVotes = getGrantVotes[_receiver].noVotes + voteNumber;
			//individualVote.noVotes = voteNumber;
		}
		//getGrantVotes[_receiver].hasvoted[msg.sender] = true;
		//getGrantVotes[_receiver].individualVotes.push(individualVote);
		getGrantVotes[_receiver].voteNumber = getGrantVotes[_receiver].voteNumber + 1;	
	}

	/**
    * @notice A method that checks if an address has already voted in a grant Vote.
    * @param _address Address that is checked
    *        _receiver Address for which the voting process should be checked
    */
    function checkIfVotedGrantFunding(
		address _address, 
		address _receiver
		) 
		external
		view
		returns(bool)
		{
		uint256 voteID = lastGrantVoteIDByReceiver[_receiver];
		return (hasVoted[voteID][_address]);
	}

	
	/**
    * @notice A method that closes a specific grant funding voting process.
    * @param _receiver Address for which the voting process should be closed
    */
    function closeGrantFundingVote (
		address _receiver
		)
		external 
		notPaused
		{
		require(getGrantVotes[_receiver].exists,'VOTEID_UNKNOWN'); //checks if the vote id exists)
		require(getGrantVotes[_receiver].open,'VOTE_NOT_OPEN'); //checks is the vote is open)
		require(getGrantVotes[_receiver].endingTime < block.timestamp);
		getGrantVotes[_receiver].open = false;
		
		
		if (getGrantVotes[_receiver].yesVotes > getGrantVotes[_receiver].noVotes){
			governanceToken.transfer(_receiver,getGrantVotes[_receiver].amount);
			emit grantFundingVoteClosed(_receiver,true);	
			}
		else {
			emit grantFundingVoteClosed(_receiver,false);
			DAOVolume = DAOVolume + getGrantVotes[_receiver].amount;
		}
		
		
		//delete(getGrantVotes[_receiver]);
		//emit grantFundingVoteClosed(_receiver,true);		
	}

	/**
	* @notice A method that gets the details of a specific grant poposal Vote
	* @param _address Address to check
	*/
	function getGrantVoteDetails(
		address _address
		)
		external
		view
		//returns (uint256,uint256,uint256,uint256,bool,bool,uint256,string memory)
		returns (uint256,uint256,uint256,uint256,string memory,bool)
		{
			//uint256 startingTime = getGrantVotes[_address].startingTime;
			uint256 endingTime = getGrantVotes[_address].endingTime;
			uint256 yesVotes = getGrantVotes[_address].yesVotes;
			uint256 noVotes = getGrantVotes[_address].noVotes;
			uint256 grantAmount = getGrantVotes[_address].amount;
			//bool proposalExists = getGrantVotes[_address].exists;
			string memory description = getGrantVotes[_address].description;
			bool grantVoteOpen = getGrantVotes[_address].open;
			
			return (endingTime,yesVotes,noVotes,grantAmount,description,grantVoteOpen);
		}


	// NEW ASSET CREATION STARTING HERE




}