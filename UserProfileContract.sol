// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract UserProfileContract {
    struct UserProfile {
        string username;
        string skills;
        uint256 ratings;
    }

    mapping(address => UserProfile) public userProfiles;

    event UserProfileCreated(address indexed user, string username, string skills);

    function createUserProfile(string memory _username, string memory _skills) external {
        require(bytes(userProfiles[msg.sender].username).length == 0, "Profile already exists.");
        userProfiles[msg.sender] = UserProfile(_username, _skills, 0);
        emit UserProfileCreated(msg.sender, _username, _skills);
    }

    function updateProfile(string memory _username, string memory _skills) external {
        require(bytes(_username).length > 0, "Username cannot be empty.");
        require(bytes(_skills).length > 0, "Skills cannot be empty.");
        require(bytes(userProfiles[msg.sender].username).length > 0, "Profile does not exist.");
        userProfiles[msg.sender].username = _username;
        userProfiles[msg.sender].skills = _skills;
    }

    function updateRatings(address _user, uint256 _ratings) external {
        require(msg.sender == _user || bytes(userProfiles[msg.sender].username).length == 0, "You can only update your own ratings.");
        userProfiles[_user].ratings = _ratings;
    }

    function getUserProfile(address _user) external view returns (string memory, string memory, uint256) {
        UserProfile storage userProfile = userProfiles[_user];
        return (userProfile.username, userProfile.skills, userProfile.ratings);
    }
}
