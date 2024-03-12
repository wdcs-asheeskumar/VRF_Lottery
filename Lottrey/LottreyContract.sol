//SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract LottreyContract {
    VRFCoordinatorV2Interface COORDINATOR;
    uint64 subscriptionId;
    address vrfCoordinator = 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625;
    bytes32 keyHash =
        0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c;
    uint32 callbackGasLimit = 100000;
    uint16 requestConfirmation = 3;
    uint8 numWords = 0;
    uint256 public requestIde;
    uint256 public requestIde1;
    uint256 public arrLength;
    struct LottreyData {
        address lottreyOperator;
        uint256 ticketPrice;
        uint256 maxTicket;
        uint256 lotteryOperatorComission;
        uint256 expiration;
        address lottreyWinner;
        address[] ticket;
    }

    struct LottreyStatus {
        uint256 lottreyId;
        bool fullfilled;
        bool exists;
        uint256[] randomNumber;
    }

    mapping(uint256 => LottreyData) public lottrey;
    mapping(uint256 => LottreyStatus) public request;
    uint256 public lottreyCount;

    constructor(uint64 _subscriptionId) {
        subscriptionId = _subscriptionId;
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
    }

    modifier onlyOperator(uint256 _lotteryId) {
        require(
            msg.sender == lottrey[_lotteryId].lottreyOperator,
            "Only operator can own it"
        );
        _;
    }

    modifier canClaim(uint256 _lotteryId) {
        require(
            msg.sender == lottrey[_lotteryId].lottreyOperator ||
                msg.sender == lottrey[_lotteryId].lottreyWinner,
            "Invalid address"
        );
        require(
            lottrey[_lotteryId].lottreyWinner != address(0),
            "Invalid address"
        );
        _;
    }

    function getRemainingTickets(uint256 _lotteryId)
        public
        view
        returns (uint256)
    {
        return
            lottrey[_lotteryId].maxTicket - lottrey[_lotteryId].ticket.length;
    }

    // create lottrey
    function startLottrey(
        address _lottreyOperator,
        uint256 _ticketPrice,
        uint256 _maxTicket,
        uint256 _lotteryOperatorComission,
        uint256 _expiration
    ) public {
        require(_lottreyOperator != address(0), "Invalid address");
        require(_lotteryOperatorComission > 0 || _lotteryOperatorComission < 5);
        require(_expiration > block.timestamp);
        require(_ticketPrice > 0);
        require(_maxTicket > 0);
        address[] memory ticketsArray;
        lottreyCount++;
        lottrey[lottreyCount].lottreyOperator = _lottreyOperator;
        lottrey[lottreyCount].ticketPrice = _ticketPrice;
        lottrey[lottreyCount].maxTicket = _maxTicket;
        lottrey[lottreyCount]
            .lotteryOperatorComission = _lotteryOperatorComission;
        lottrey[lottreyCount].expiration = _expiration;
        lottrey[lottreyCount].lottreyWinner = address(0);
        lottrey[lottreyCount].ticket = ticketsArray;
    }

    // buy lottrey
    function buyLottrey(uint256 _lottreyId, uint256 _tickets) public payable {
        uint256 amount = msg.value;
        require(_tickets > 0, "Invalid argument");
        require(amount >= _tickets * lottrey[_lottreyId].ticketPrice);
        require(
            block.timestamp < lottrey[lottreyCount].expiration,
            "Lottrey has to be of valid time period"
        );
        for (uint256 i = 0; i < _tickets; i++) {
            lottrey[_lottreyId].ticket.push(msg.sender);
        }
    }

    // draw lottrey winner
    function drawLottreyWinner(uint256 _lotteryId)
        public
        onlyOperator(_lotteryId)
        returns (uint256 requestId)
    {
        require(
            block.timestamp >= lottrey[_lotteryId].expiration,
            "Lottery is still active"
        );
        requestId = COORDINATOR.requestRandomWords(
            keyHash,
            subscriptionId,
            requestConfirmation,
            callbackGasLimit,
            numWords
        );
        requestIde = (requestId);
        arrLength = lottrey[_lotteryId].ticket.length;
        requestIde1 = (requestIde) % (arrLength);
        requestId = requestIde1;
        request[requestId].lottreyId = _lotteryId;
        request[requestId].fullfilled = false;
        request[requestId].exists = true;
        request[requestId].randomNumber = new uint256[](0);
        lottrey[_lotteryId].lottreyWinner = lottrey[_lotteryId].ticket[
            requestId - 1
        ];
    }

    // claim lottrey
    function takeLottrey(uint256 _lottreyId) public canClaim(_lottreyId) {
        uint256 winningAmount = lottrey[_lottreyId].ticket.length *
            lottrey[_lottreyId].ticketPrice;
        uint256 operatorComission = (winningAmount *
            lottrey[_lottreyId].lotteryOperatorComission) / 100;
        (bool sentComission, ) = payable(lottrey[_lottreyId].lottreyOperator)
            .call{value: operatorComission}("");
        require(sentComission);

        uint256 winnersAmount = winningAmount - operatorComission;
        (bool sentWinningAmount, ) = payable(lottrey[_lottreyId].lottreyWinner)
            .call{value: winnersAmount}("");
        require(sentWinningAmount);
    }
}
