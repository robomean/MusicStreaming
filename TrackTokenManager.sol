// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./MusicTracks.sol";

contract TrackTokenManager {
    MusicTracks public musicTracks;

    struct TokenizedTrack {
        uint256 totalShares;
        uint256 remainingShares;
        uint256 sharePrice;
        mapping(address => uint256) balances;
    }

    mapping(uint256 => TokenizedTrack) public tokenizedTracks;
    mapping(uint256 => uint256) public dividendsPool;

    event TrackTokenized(uint256 indexed trackId, uint256 totalShares, uint256 sharePrice);
    event SharesPurchased(uint256 indexed trackId, address indexed buyer, uint256 shares);
    event DividendsClaimed(uint256 indexed trackId, address indexed holder, uint256 amount);

    constructor(address _musicTracksContract) {
        require(_musicTracksContract != address(0), "Invalid MusicTracks address");
        musicTracks = MusicTracks(_musicTracksContract);
    }

    function tokenizeTrack(
        uint256 _trackId,
        uint256 _totalShares,
        uint256 _sharePrice
    ) external {
        (, , , address artist, , ) = musicTracks.getTrack(_trackId);
        require(artist == msg.sender, "Caller is not the artist of this track");
        require(_totalShares > 0, "Total shares must be greater than zero");
        require(_sharePrice > 0, "Share price must be greater than zero");
        require(tokenizedTracks[_trackId].totalShares == 0, "Track already tokenized");

        tokenizedTracks[_trackId].totalShares = _totalShares;
        tokenizedTracks[_trackId].remainingShares = _totalShares;
        tokenizedTracks[_trackId].sharePrice = _sharePrice;

        emit TrackTokenized(_trackId, _totalShares, _sharePrice);
    }

    function isTokenized(uint256 _trackId) public view returns (bool) {
        return tokenizedTracks[_trackId].totalShares > 0;
    }

    function buyTrackShares(uint256 _trackId, uint256 _amount) external payable {
        TokenizedTrack storage tokenizedTrack = tokenizedTracks[_trackId];
        require(tokenizedTrack.totalShares > 0, "Track is not tokenized");
        require(_amount > 0, "Amount of shares must be greater than zero");

        (, , , address artist, , ) = musicTracks.getTrack(_trackId);

        uint256 totalCost = _amount * tokenizedTrack.sharePrice;
        require(msg.value >= totalCost, "Insufficient payment");
        require(tokenizedTrack.remainingShares >= _amount, "Not enough shares available");

        tokenizedTrack.remainingShares -= _amount;

        tokenizedTrack.balances[msg.sender] += _amount;

        payable(artist).transfer(totalCost);

        uint256 excess = msg.value - totalCost;
        if (excess > 0) {
            payable(msg.sender).transfer(excess);
        }

        emit SharesPurchased(_trackId, msg.sender, _amount);
    }

    function claimDividends(uint256 _trackId) external {
        TokenizedTrack storage tokenizedTrack = tokenizedTracks[_trackId];
        require(tokenizedTrack.balances[msg.sender] > 0, "No shares owned");

        uint256 totalDividends = dividendsPool[_trackId];
        require(totalDividends > 0, "No dividends available");

        uint256 holderBalance = tokenizedTrack.balances[msg.sender];
        uint256 holderShare = (totalDividends * holderBalance) / tokenizedTrack.totalShares;
        require(holderShare > 0, "No dividends for your share");

        uint256 artistShareUnclaimed = (totalDividends * tokenizedTrack.remainingShares) / tokenizedTrack.totalShares;
        
        dividendsPool[_trackId] -= (holderShare + artistShareUnclaimed);

        (, , , address artist, , ) = musicTracks.getTrack(_trackId);
        payable(artist).transfer(artistShareUnclaimed);

        payable(msg.sender).transfer(holderShare);

        emit DividendsClaimed(_trackId, msg.sender, holderShare);
    }

    function addDividends(uint256 _trackId) external payable returns (bool) {
        require(tokenizedTracks[_trackId].totalShares > 0, "Track not tokenized");
        require(msg.value > 0, "Must send ETH to add dividends");

        dividendsPool[_trackId] += msg.value;
        return true;
    }
}