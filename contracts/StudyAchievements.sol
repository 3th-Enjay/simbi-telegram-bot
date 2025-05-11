// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title StudyAchievements
 * @dev ERC721 contract for managing educational achievement NFTs
 */
contract StudyAchievements is ERC721URIStorage, AccessControl {
    // Token ID counter for sequential minting
    uint256 private _tokenIdCounter;
    
    // Base URI for computing {tokenURI}
    string private _baseTokenURI;
    
    // Role definitions
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    // Achievement types
    enum AchievementType { MathMaster, CodeNinja, ResearchPro }
    
    // Track which addresses have which achievements
    mapping(address => mapping(AchievementType => bool)) private _achievements;
    
    // Map token IDs to achievement types
    mapping(uint256 => AchievementType) private _tokenAchievements;
    
    // Emitted when a new achievement NFT is minted
    event AchievementMinted(
        address indexed user,
        uint256 indexed tokenId,
        AchievementType achievementType,
        string tokenURI
    );
    
    /**
     * @dev Initializes the contract by setting a name and symbol for the token collection
     * and granting DEFAULT_ADMIN_ROLE and MINTER_ROLE to the deployer
     */
    constructor(string memory baseURI_) ERC721("StudyAchievements", "STUDY") {
        _baseTokenURI = baseURI_;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
    }
    
    /**
     * @dev Mints a new achievement NFT
     * @param user Address to receive the achievement
     * @param achievementType Type of achievement being granted
     * @param tokenURI_ Metadata URI for the achievement token
     */
    function mintAchievementNFT(
        address user,
        AchievementType achievementType,
        string memory tokenURI_
    ) external onlyRole(MINTER_ROLE) {
        require(user != address(0), "Invalid address");
        require(!_achievements[user][achievementType], "Achievement already granted");
        require(bytes(tokenURI_).length > 0, "Empty metadata");
        
        uint256 tokenId = _tokenIdCounter;
        _tokenIdCounter++;
        
        _safeMint(user, tokenId);
        _setTokenURI(tokenId, tokenURI_);
        _achievements[user][achievementType] = true;
        _tokenAchievements[tokenId] = achievementType;
        
        emit AchievementMinted(user, tokenId, achievementType, tokenURI_);
    }
    
    /**
     * @dev Checks if a user has a specific achievement
     * @param user Address to check
     * @param achievementType Achievement type to check for
     * @return bool True if the user has the achievement
     */
    function hasAchievement(address user, AchievementType achievementType) 
        public view returns (bool) 
    {
        return _achievements[user][achievementType];
    }
    
    /**
     * @dev Gets all achievements for a user
     * @param user Address to check
     * @return Array of booleans representing achievement status
     */
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
    
    /**
     * @dev Sets the base URI for all token IDs
     * @param baseURI New base URI
     */
    function setBaseURI(string memory baseURI) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _baseTokenURI = baseURI;
    }
    
    /**
     * @dev Overrides the baseURI function
     * @return string Base URI for computing {tokenURI}
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    
    /**
     * @dev Burns a token
     * @param tokenId ID of the token to burn
     */
    function burn(uint256 tokenId) external {
        require(
            _isOwner(msg.sender, tokenId) || 
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Not token owner or admin"
        );
        
        // Get token owner
        address owner = ownerOf(tokenId);
        
        // Get achievement type
        AchievementType achievementType = _tokenAchievements[tokenId];
        
        // Reset achievement status
        _achievements[owner][achievementType] = false;
        
        // Burn the token
        _burn(tokenId);
    }
    
    /**
     * @dev Checks if address is the owner of a token
     * @param addr Address to check
     * @param tokenId Token ID to check
     * @return bool True if addr is the token owner
     */
    function _isOwner(address addr, uint256 tokenId) internal view returns (bool) {
        return ownerOf(tokenId) == addr;
    }
    
    /**
     * @dev Resolves conflicts between inherited contracts
     * @param interfaceId Interface identifier
     * @return bool True if this contract implements the interface
     */
    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721URIStorage, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}