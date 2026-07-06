
```swift
static let ResponseCodes : [ String : Int ] = [
        "INITIALIZE" : 1,
        "AUTH" : 2,
        "LOGOUT" : 3,
        "UPDATE_GAME_SERVER" : 4,
        "DELETE_ACCOUNT" : 5,
        "REFRESH_TOKEN" : 6,
        "GET_LATEST_SESSION" : 7,
        "USER_BLOCKED" : 8,
        "FORCE_UPDATE" : 9
    ]
```

```swift
static let ResultCodes : [ String : Int ] = [
    "FAIL" : -1,
    "CANCEL" : 0,
    "SUCCESS" : 1
]
```

# 1. Force Update
replace your app-store-id
```swift
ForceUpdateView(appStoreId: "123")
```

Start app -> Init SDK.


```json
{
  "ResponseCode": 9,
  "ResultCode": 1
}
```

# 2.1 User Blocked
Start app -> Init SDK -> USER_BLOCKED
```json
{
  "UserBlocked": true,
  "ResultCode": 1,
  "GameBlocked": false,
  "ServerBlocked": false,
  "GameUUID": "1953864126871937024",
  "ResponseCode": 8,
  "RefreshToken": "0dKTE6hPPwu9h5Gz9QSVB6cg1bfHcFtXtrVCYs2Ifkk",
  "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VJZCI6IjcyMjZEOTYwLThFOTgtNDZCMi1CRDU3LTQzNzE3NzZDRkVBMiIsImF1ZCI6IlNES1VTRVIiLCJzdWIiOiIxOTUzODQ0MTcyMTY0NDcyODMyIiwiaWF0IjoxNzU0NjcyMDM2LCJleHAiOjE3NTQ3NTg0MzZ9.ViPiDOI2l6dSUss6vjF5cxGpYepKwwSchjIsiUYPY2s"
}
```

# 2.2 User Blocked close
Start app -> Init SDK -> USER_BLOCKED -> close
```json
{
    "ResultCode":0,
    "ResponseCode":8
}
```

# 3.1 INITILIZE success
Start app -> Init SDK --> INITILIZE success
```json
{
  "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VJZCI6IjcyMjZEOTYwLThFOTgtNDZCMi1CRDU3LTQzNzE3NzZDRkVBMiIsImF1ZCI6IlNES1VTRVIiLCJzdWIiOiIxOTUzODQ0MTcyMTY0NDcyODMyIiwiaWF0IjoxNzU0NjczMzgyLCJleHAiOjE3NTQ3NTk3ODJ9.-qGpf2OurFJ4elikQS7qz2PTmHESyPpBFyOLQ-GKFGk",
  "RefreshToken": "TF74rwLxestNGRdWGEeBjFWjTLGeFKvO-rwZRQnN3lA",
  "UserBlocked": false,
  "ResponseCode": 1,
  "GameUUID": "1953864277233541120",
  "ServerBlocked": false,
  "ServerID": 30,
  "GameBlocked": false,
  "ResultCode": 1
}
```

# 3.2 INITILIZE fail
Start app -> Init SDK --> INITILIZE fail
```json
{
    // TODO
}
```

# 4.1 AUTH fail
Start app -> Init SDK success -> Login fail
```json
{
  "Code": -404,
  "ResponseCode": 2,
  "Message": "Account is deleted, or not registered",
  "ResultCode": -1
}
```
# 4.2 AUTH success
Start app -> Init SDK success -> Login success
```json
{
  "ResultCode": 1,
  "RefreshToken": "bHRy69SKM_Psy5POjgCthWlPau6QfrwIwoJ5GNopVwM",
  "GameBlocked": false,
  "UserBlocked": false,
  "ResponseCode": 2,
  "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VJZCI6IjcyMjZEOTYwLThFOTgtNDZCMi1CRDU3LTQzNzE3NzZDRkVBMiIsImF1ZCI6IlNES1VTRVIiLCJzdWIiOiIxOTUzODQ0MTcyMTY0NDcyODMyIiwiaWF0IjoxNzU0Njc1MjM3LCJleHAiOjE3NTQ3NjE2Mzd9.fnJTntoWQbQLoqxLvVU8CxfF7E8Zta6J2q92lMKtkSc",
  "ServerBlocked": false,
  "GameUUID": "1953864277233541120",
  "ServerID": 30
}
```

# 5. REFRESH_TOKEN success
```json
{
  "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VJZCI6IjcyMjZEOTYwLThFOTgtNDZCMi1CRDU3LTQzNzE3NzZDRkVBMiIsImF1ZCI6IlNES1VTRVIiLCJzdWIiOiIxOTUzODQ0MTcyMTY0NDcyODMyIiwiaWF0IjoxNzU0Njc1MzQ2LCJleHAiOjE3NTQ3NjE3NDZ9.dm3Z5qjzpllEGSXq-NJzASJO_Ma6Nd03lM4J52meoCU",
  "ResponseCode": 6,
  "GameUUID": "1953864277233541120",
  "ResultCode": 1,
  "RefreshToken": "mzuDpqk9O2ZUOsVONlDdZyeX4vzV2R9dTFPY5M_hGfk"
}
```

# 6. Get Latest Session
```json
{
  "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VJZCI6IjcyMjZEOTYwLThFOTgtNDZCMi1CRDU3LTQzNzE3NzZDRkVBMiIsImF1ZCI6IlNES1VTRVIiLCJzdWIiOiIxOTUzODQ0MTcyMTY0NDcyODMyIiwiaWF0IjoxNzU0Njc1MzQ2LCJleHAiOjE3NTQ3NjE3NDZ9.dm3Z5qjzpllEGSXq-NJzASJO_Ma6Nd03lM4J52meoCU",
  "ResponseCode": 7,
  "ResultCode": 1,
  "GameUUID": "1953864277233541120",
  "RefreshToken": "mzuDpqk9O2ZUOsVONlDdZyeX4vzV2R9dTFPY5M_hGfk"
}
```

# 7. Update Game Server
```json
{
  "GameUUID": "1953864126871937024",
  "ServerID": 1,
  "UserBlocked": false,
  "ResultCode": 1,
  "GameBlocked": false,
  "ServerBlocked": false,
  "RefreshToken": "bHRy69SKM_Psy5POjgCthWlPau6QfrwIwoJ5GNopVwM",
  "ResponseCode": 4,
  "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VJZCI6IjcyMjZEOTYwLThFOTgtNDZCMi1CRDU3LTQzNzE3NzZDRkVBMiIsImF1ZCI6IlNES1VTRVIiLCJzdWIiOiIxOTUzODQ0MTcyMTY0NDcyODMyIiwiaWF0IjoxNzU0Njc1MjM3LCJleHAiOjE3NTQ3NjE2Mzd9.fnJTntoWQbQLoqxLvVU8CxfF7E8Zta6J2q92lMKtkSc"
}
```

# 8. Logout
```json
{
  "GameUUID": "1953864277233541120",
  "ServerID": 30,
  "UserBlocked": false,
  "ResultCode": 1,
  "GameBlocked": false,
  "ServerBlocked": false,
  "RefreshToken": "bHRy69SKM_Psy5POjgCthWlPau6QfrwIwoJ5GNopVwM",
  "ResponseCode": 3,
  "AccessToken": "eyJhbGciOiJIUzI1NiJ9.eyJkZXZpY2VJZCI6IjcyMjZEOTYwLThFOTgtNDZCMi1CRDU3LTQzNzE3NzZDRkVBMiIsImF1ZCI6IlNES1VTRVIiLCJzdWIiOiIxOTUzODQ0MTcyMTY0NDcyODMyIiwiaWF0IjoxNzU0Njc1MjM3LCJleHAiOjE3NTQ3NjE2Mzd9.fnJTntoWQbQLoqxLvVU8CxfF7E8Zta6J2q92lMKtkSc"
}
```

# 9.1 Delete account cancel
```json
{
    "ResultCode":0,
    "ResponseCode":5
}
```

# 9.2 Delete account success
```json
{
    "ResultCode":1,
    "ResponseCode":5
}
```