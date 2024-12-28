// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./TrackTokenManager.sol";

contract MusicTracks is Ownable {
    struct Track {
        uint256 id;
        string title;
        string ipfsHash;
        address artist;
        uint256 playCount;
    }

    mapping(uint256 => Track) public tracks;
    mapping(uint256 => uint256) public trackPrices;
    mapping(address => uint256) public artistBalances;

    uint256 public nextTrackId = 1;
    mapping(address => bool) public approvedArtists;

    TrackTokenManager public trackTokenManager;

    event TrackUploaded(uint256 indexed trackId, string title, address indexed artist);
    event TrackStreamed(uint256 indexed trackId, address indexed listener, uint256 amountPaid);

    modifier onlyArtist() {
        require(approvedArtists[msg.sender], "Caller is not an approved artist");
        _;
    }

    constructor() Ownable(msg.sender) {}

    function setTrackTokenManager(address _trackTokenManager) external onlyOwner {
        require(_trackTokenManager != address(0), "Invalid address for TrackTokenManager");
        trackTokenManager = TrackTokenManager(_trackTokenManager);
    }

    function addArtist(address _artist) external onlyOwner {
        require(_artist != address(0), "Invalid artist address");
        approvedArtists[_artist] = true;
    }

    function uploadTrack(
        string memory _title,
        string memory _ipfsHash,
        uint256 _pricePerPlay
    ) external onlyArtist {
        require(bytes(_title).length > 0, "Invalid title");
        require(bytes(_ipfsHash).length > 0, "Invalid IPFS hash");
        require(_pricePerPlay > 0, "Price per play must be greater than zero");

        tracks[nextTrackId] = Track({
            id: nextTrackId,
            title: _title,
            ipfsHash: _ipfsHash,
            artist: msg.sender,
            playCount: 0
        });

        trackPrices[nextTrackId] = _pricePerPlay;

        emit TrackUploaded(nextTrackId, _title, msg.sender);
        nextTrackId++;
    }

    function streamTrack(uint256 _trackId) external payable {
        require(tracks[_trackId].id != 0, "Track does not exist");
        uint256 trackPrice = trackPrices[_trackId];
        require(msg.value >= trackPrice, "Insufficient payment to stream");

        Track storage track = tracks[_trackId];
        track.playCount++;

        uint256 artistShare;
        uint256 dividendShare;

        if (address(trackTokenManager) != address(0) && trackTokenManager.isTokenized(_trackId)) {
            artistShare = (msg.value * 70) / 100;
            dividendShare = msg.value - artistShare;

            artistBalances[track.artist] += artistShare;
            trackTokenManager.addDividends{value: dividendShare}(_trackId);
        } else {
            artistShare = msg.value;
            artistBalances[track.artist] += artistShare;
        }

        emit TrackStreamed(_trackId, msg.sender, trackPrice);
    }

    function withdrawArtistFunds() external {
        uint256 balance = artistBalances[msg.sender];
        require(balance > 0, "No funds to withdraw");

        artistBalances[msg.sender] = 0;

        payable(msg.sender).transfer(balance);
    }

    function getTrack(uint256 _trackId) external view returns (
        uint256 id,
        string memory title,
        string memory ipfsHash,
        address artist,
        uint256 playCount,
        uint256 trackPrice
    ) {
        require(tracks[_trackId].id != 0, "Track does not exist");
        Track memory track = tracks[_trackId];
        return (track.id, track.title, track.ipfsHash, track.artist, track.playCount, trackPrices[_trackId]);
    }
}