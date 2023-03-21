 // SPDX-License-Identifier: MIT

pragma solidity >=0.7.0 <0.9.0;

interface IERC20Token {
   function transfer(address, uint256) external returns (bool);

   function approve(address, uint256) external returns (bool);

   function transferFrom(
       address,
       address,
       uint256
   ) external returns (bool);

   function totalSupply() external view returns (uint256);

   function balanceOf(address) external view returns (uint256);

   function allowance(address, address) external view returns (uint256);

   event Transfer(address indexed from, address indexed to, uint256 value);
   event Approval(
       address indexed owner,
       address indexed spender,
       uint256 value
   );
}

contract LandAuction {
   uint256 internal landsLength = 0;

   address internal cUsdTokenAddress =
       0x874069Fa1Eb16D44d622F2e0Ca25eeA172369bC1;

   struct Land {
       address payable owner;
       string location;
       string description;
       uint256 price;
       uint256 sold;
       bool soldStatus;
       uint256 highestBid;
       address payable highestBidder;
       uint256 auctionEndTime;
   }
   mapping(uint256 => Land) private lands;

   mapping(uint256 => bool) private _exists;

   // check if a land with id of _index exists
   modifier exists(uint256 _index) {
       require(_exists[_index], "Query of a nonexistent land");
       _;
   }

   // checks if the input data for location and description are non-empty values
   modifier checkInputData(string calldata _location, string calldata _description) {
       require(bytes(_location).length > 0, "Empty location");
       require(bytes(_description).length > 0, "Empty description");
       _;
   }

   function addLand(
       string calldata _location,
       string calldata _description,
       uint256 _price,
       uint256 _auctionEndTime
   ) public checkInputData(_location, _description) {
       require(_auctionEndTime > block.timestamp, "Auction end time must be in the future");
       uint256 _sold = 0;
       uint256 index = landsLength;
       landsLength++;
       lands[index] = Land(
           payable(msg.sender),
           _location,
           _description,
           _price,
           _sold,
           false,
           0,
           payable(address(0)),
           _auctionEndTime
       );
       _exists[index] = true;
   }

   function readLand(uint256 _index) public view exists(_index) returns (Land memory) {
       return lands[_index];
   }


   function placeBid(uint256 _index) public payable exists(_index) {
       require(block.timestamp < lands[_index].auctionEndTime, "Auction has ended");
       require(msg.sender != lands[_index].owner, "Owner cannot place a bid");
       require(msg.value > lands[_index].highestBid, "Bid must be higher than the current highest bid");
       if (lands[_index].highestBid != 0) {
           // if there is already a highest bid, return the previous bid amount to the previous highest bidder
           require(lands[_index].highestBidder.send(lands[_index].highestBid), "Failed to return previous highest bid");
       }
       lands[_index].highestBid = msg.value;
       lands[_index].highestBidder = payable(msg.sender);
   }

  function buyLand(uint256 _index) public payable exists(_index) {
   require(lands[_index].auctionEndTime < block.timestamp, "Auction not ended");
   require(!lands[_index].soldStatus, "Land already sold");
   require(msg.sender != lands[_index].owner, "Owner cannot buy the land");

   if (lands[_index].highestBid > 0) {
       // transfer the highest bid amount to the previous owner
       require(IERC20Token(cUsdTokenAddress).transferFrom(msg.sender, lands[_index].owner, lands[_index].highestBid), "Transfer failed");
   } else {
       // transfer the price to the owner if there were no bids
       require(IERC20Token(cUsdTokenAddress).transferFrom(msg.sender, lands[_index].owner, lands[_index].price), "Transfer failed");
   }

   // update the land sold status and owner
   lands[_index].sold = lands[_index].highestBid > 0 ? lands[_index].highestBid : lands[_index].price;
   lands[_index].soldStatus = true;
   lands[_index].owner = payable(msg.sender);
}
function cancelAuction(uint256 _index) public exists(_index) {
    require(msg.sender == lands[_index].owner, "Only owner can cancel auction");
    require(!lands[_index].soldStatus, "Land has already been sold");
    if (lands[_index].highestBid != 0) {
        require(lands[_index].highestBidder.send(lands[_index].highestBid), "Failed to return highest bid");
    }
    lands[_index].auctionEndTime = block.timestamp; // set auction end time to current time to end auction
}

}
