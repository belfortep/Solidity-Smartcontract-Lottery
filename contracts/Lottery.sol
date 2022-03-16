//SPDX-License-Identifier: MIT
pragma solidity ^0.6.6;

import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Lottery is VRFConsumerBase, Ownable {
    address payable[] public players;
    uint256 public usdEntryFee;
    address payable public recentWinner;
    uint256 public randomness;
    AggregatorV3Interface internal ethUsdPriceFeed;
    enum LOTTERY_STATE {
        OPEN,
        CLOSED,
        CALCULATING_WINNER
    } //enum, representa el estado de mi aplicacion
    LOTTERY_STATE public lottery_state;
    uint256 public fee; //lo que hay que pagar para el numero random
    bytes32 public keyhash;
    event RequestedRandomness(bytes32 requestId); //los eventos envian datos

    //OPEN == 0, CLOSED ==1, CALC WINNER ==2
    constructor(
        address _priceFeedAddress,
        address _vrfCoordinator,
        address _link,
        uint256 _fee,
        bytes32 _keyhash
    ) public VRFConsumerBase(_vrfCoordinator, _link) {
        usdEntryFee = 50 * (10**18); //el equivalente a 50 dolares ee.uu
        ethUsdPriceFeed = AggregatorV3Interface(_priceFeedAddress);
        lottery_state = LOTTERY_STATE.CLOSED;
        fee = _fee;
        keyhash = _keyhash;
    }

    function enter() public payable {
        require(lottery_state == LOTTERY_STATE.OPEN);
        require(msg.value >= getEntranceFee(), "Dinero insuficiente");
        players.push(msg.sender); //meto a quien llama a esta funcion a jugador
    }

    function getEntranceFee() public view returns (uint256) {
        (, int256 price, , , ) = ethUsdPriceFeed.latestRoundData();
        uint256 adjustedPrice = uint256(price) * 10**10;
        uint256 costToEnter = (usdEntryFee * 10**18) / adjustedPrice;
        return costToEnter;
    }

    function startLottery() public onlyOwner {
        require(
            lottery_state == LOTTERY_STATE.CLOSED,
            "No se puede empezar una nueva loteria :c"
        );
        lottery_state = LOTTERY_STATE.OPEN;
    }

    function endLoterry() public onlyOwner {
        //uint256(
        //    keccak256(
        //        abi.encodePacked(
        //            nonce,
        //            msg.sender,
        //            block.difficulty,
        //            block.timestamp
        //        ) //estos son varios numeros semialeatorios, los meto todos juntos a un metodo de HASH y lo que salga lo divido por la cantidad de jugadores y el resto es el ganador, medio lol
        //    )   //pero claro, esto no es seguro del todo. la mayoria son predecibles
        //) % players.length;
        lottery_state = LOTTERY_STATE.CALCULATING_WINNER;
        bytes32 requestId = requestRandomness(keyhash, fee); //devuelve un bytes32 con nombre requestId
        emit RequestedRandomness(requestId); //aca se manda el evento
    } //Esto funciona con la manera clasica de request, response. le pido el numero random al VRF, y despues este lo tiene que verificar

    //solo mi nodo de la chainlink debe llamar a esta funcion

    function fulfillRandomness(bytes32 _requestId, uint256 _randomness)
        internal
        override
    {
        require(
            lottery_state == LOTTERY_STATE.CALCULATING_WINNER,
            "que haces papu"
        );
        require(_randomness > 0, "alto nub");
        uint256 indexOfWinner = _randomness % players.length;
        recentWinner = players[indexOfWinner];
        recentWinner.transfer(address(this).balance); //al ganador, transferile todo el dinero que tenga este contrato
        //reseteo
        players = new address payable[](0);
        lottery_state = LOTTERY_STATE.CLOSED;
        randomness = _randomness;
    }

    //override es que estoy sobreescribiendo a una funcion
}
