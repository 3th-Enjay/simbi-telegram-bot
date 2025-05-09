// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract StudyAchievements is ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;
    string private _baseTokenURI;

    enum AchievementType { MathMaster, CodeNinja, ResearchPro }

    // Prevent minting duplicate achievements to the same user
    mapping(address => mapping(AchievementType => bool)) private _achievements;

    event AchievementMinted(
        address indexed user,
        uint256 indexed tokenId,
        AchievementType achievementType,
        string tokenURI
    );

    constructor() ERC721("StudyAchievements", "STUDY") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }

    function mintAchievementNFT(
        address user,
        AchievementType achievementType,
        string memory tokenURI_
    ) external onlyRole(MINTER_ROLE) {
        require(user != address(0), "Invalid address");
        require(!_achievements[user][achievementType], "Achievement already granted");
        require(bytes(tokenURI_).length > 0, "Empty metadata");

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(user, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        _achievements[user][achievementType] = true;

        emit AchievementMinted(user, tokenId, achievementType, tokenURI_);
    }

    function hasAchievement(address user, AchievementType achievementType) 
        public view returns (bool) 
    {
        return _achievements[user][achievementType];
    }

    function getUserAchievements(address user) 
        external view returns (bool[] memory) 
    {
        uint256 totalTypes = uint256(type(AchievementType).max) + 1;
        bool[] memory achievements = new bool[](totalTypes);
        for (uint256 i = 0; i < totalTypes; i++) {
            achievements[i] = _achievements[user][AchievementType(i)];
        }
        return achievements;
    }

    function setBaseURI(string memory baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId)
        public view override returns (string memory) 
    {
        require(_exists(tokenId), "Nonexistent token");
        string memory base = _baseTokenURI;
        string memory specific = super.tokenURI(tokenId);
        return bytes(base).length > 0 ? string(abi.encodePacked(base, specific)) : specific;
    }

    function burn(uint256 tokenId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_exists(tokenId), "Token does not exist");
        _burn(tokenId);
        // NOTE: The _achievements mapping is not reverted on burn for history traceability
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
