//
//  ComplexPerformanceTests.swift
//  ReerJSON
//
//  Created by phoenix on 2025/7/18.
//


import XCTest
@testable import ReerJSON

final class ComplexPerformanceTests: XCTestCase {
    
    // MARK: - 复杂数据结构定义
    
    struct APIResponse: Codable {
        let status: String
        let code: Int
        let message: String
        let timestamp: Double
        let data: ResponseData
        let pagination: Pagination
        let metadata: [String: String]
    }
    
    struct ResponseData: Codable {
        let users: [User]
        let companies: [Company]
        let stats: Statistics
    }
    
    struct User: Codable {
        let id: Int
        let username: String
        let email: String
        let profile: UserProfile
        let settings: UserSettings
        let activities: [Activity]
        let isActive: Bool
        let lastLogin: Double
        let tags: [String]
    }
    
    struct UserProfile: Codable {
        let firstName: String
        let lastName: String
        let avatar: String
        let bio: String
        let location: Location
        let socialLinks: [SocialLink]
        let preferences: ProfilePreferences
    }
    
    struct Location: Codable {
        let country: String
        let city: String
        let latitude: Double
        let longitude: Double
        let timezone: String
    }
    
    struct SocialLink: Codable {
        let platform: String
        let url: String
        let verified: Bool
        let followerCount: Int
    }
    
    struct ProfilePreferences: Codable {
        let theme: String
        let language: String
        let notifications: NotificationSettings
        let privacy: PrivacySettings
    }
    
    struct NotificationSettings: Codable {
        let email: Bool
        let push: Bool
        let sms: Bool
        let marketing: Bool
    }
    
    struct PrivacySettings: Codable {
        let profileVisible: Bool
        let searchable: Bool
        let allowMessages: Bool
        let showOnlineStatus: Bool
    }
    
    struct UserSettings: Codable {
        let autoSave: Bool
        let twoFactorEnabled: Bool
        let sessionTimeout: Int
        let maxDevices: Int
        let apiQuota: APIQuota
    }
    
    struct APIQuota: Codable {
        let dailyLimit: Int
        let currentUsage: Int
        let resetTime: Double
        let rateLimit: RateLimit
    }
    
    struct RateLimit: Codable {
        let requestsPerMinute: Int
        let burstLimit: Int
        let windowSize: Int
    }
    
    struct Activity: Codable {
        let id: String
        let type: String
        let timestamp: Double
        let description: String
        let metadata: ActivityMetadata
        let score: Int
    }
    
    struct ActivityMetadata: Codable {
        let source: String
        let ipAddress: String
        let userAgent: String
        let duration: Int
        let success: Bool
    }
    
    struct Company: Codable {
        let id: Int
        let name: String
        let domain: String
        let industry: String
        let employees: [Employee]
        let revenue: Revenue
        let address: Address
        let contacts: [Contact]
        let founded: Int
        let isPublic: Bool
    }
    
    struct Employee: Codable {
        let id: Int
        let name: String
        let position: String
        let department: String
        let salary: Double
        let hireDate: String
        let skills: [String]
        let performance: PerformanceMetrics
    }
    
    struct PerformanceMetrics: Codable {
        let rating: Double
        let goals: [Goal]
        let achievements: [String]
        let lastReview: String
    }
    
    struct Goal: Codable {
        let title: String
        let progress: Double
        let deadline: String
        let priority: String
    }
    
    struct Revenue: Codable {
        let annual: Double
        let quarterly: [Double]
        let monthly: [Double]
        let forecast: Forecast
        let breakdown: RevenueBreakdown
    }
    
    struct Forecast: Codable {
        let nextQuarter: Double
        let nextYear: Double
        let confidence: Double
        let methodology: String
    }
    
    struct RevenueBreakdown: Codable {
        let products: [String: Double]
        let regions: [String: Double]
        let channels: [String: Double]
    }
    
    struct Address: Codable {
        let street: String
        let city: String
        let state: String
        let country: String
        let zipCode: String
        let coordinates: Coordinates
    }
    
    struct Coordinates: Codable {
        let latitude: Double
        let longitude: Double
        let elevation: Double
    }
    
    struct Contact: Codable {
        let name: String
        let email: String
        let phone: String
        let role: String
        let department: String
        let availability: ContactAvailability
    }
    
    struct ContactAvailability: Codable {
        let timezone: String
        let workingHours: WorkingHours
        let preferredMethod: String
    }
    
    struct WorkingHours: Codable {
        let start: String
        let end: String
        let days: [String]
        let holidays: [String]
    }
    
    struct Statistics: Codable {
        let totalUsers: Int
        let activeUsers: Int
        let newUsers: Int
        let churnRate: Double
        let engagement: EngagementStats
        let performance: PerformanceStats
        let geography: GeographyStats
    }
    
    struct EngagementStats: Codable {
        let dailyActive: Int
        let weeklyActive: Int
        let monthlyActive: Int
        let averageSessionDuration: Double
        let pageViews: Int
        let bounceRate: Double
    }
    
    struct PerformanceStats: Codable {
        let responseTime: Double
        let uptime: Double
        let errorRate: Double
        let throughput: Double
        let cacheHitRate: Double
    }
    
    struct GeographyStats: Codable {
        let countries: [String: Int]
        let cities: [String: Int]
        let continents: [String: Int]
    }
    
    struct Pagination: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let hasNext: Bool
        let hasPrev: Bool
        let totalPages: Int
    }
    
    // MARK: - 复杂 JSON 生成
    
    func generateComplexJSON() -> String {
        let users = (1...50).map { userId in
            """
            {
                "id": \(userId),
                "username": "user\(userId)",
                "email": "user\(userId)@example.com",
                "profile": {
                    "firstName": "First\(userId)",
                    "lastName": "Last\(userId)",
                    "avatar": "https://example.com/avatar\(userId).jpg",
                    "bio": "This is a bio for user \(userId) with some detailed information about their background and interests.",
                    "location": {
                        "country": "Country\(userId % 10)",
                        "city": "City\(userId % 20)",
                        "latitude": \(Double(userId) * 0.1),
                        "longitude": \(Double(userId) * 0.2),
                        "timezone": "UTC+\(userId % 12)"
                    },
                    "socialLinks": [
                        {
                            "platform": "Twitter",
                            "url": "https://twitter.com/user\(userId)",
                            "verified": \(userId % 3 == 0),
                            "followerCount": \(userId * 100)
                        },
                        {
                            "platform": "LinkedIn",
                            "url": "https://linkedin.com/in/user\(userId)",
                            "verified": \(userId % 5 == 0),
                            "followerCount": \(userId * 50)
                        }
                    ],
                    "preferences": {
                        "theme": "\(userId % 2 == 0 ? "dark" : "light")",
                        "language": "\(userId % 3 == 0 ? "en" : userId % 3 == 1 ? "zh" : "es")",
                        "notifications": {
                            "email": \(userId % 2 == 0),
                            "push": \(userId % 3 == 0),
                            "sms": \(userId % 4 == 0),
                            "marketing": \(userId % 5 == 0)
                        },
                        "privacy": {
                            "profileVisible": \(userId % 2 == 0),
                            "searchable": \(userId % 3 == 0),
                            "allowMessages": \(userId % 4 == 0),
                            "showOnlineStatus": \(userId % 5 == 0)
                        }
                    }
                },
                "settings": {
                    "autoSave": \(userId % 2 == 0),
                    "twoFactorEnabled": \(userId % 3 == 0),
                    "sessionTimeout": \(userId * 10 + 300),
                    "maxDevices": \(userId % 5 + 1),
                    "apiQuota": {
                        "dailyLimit": \(userId * 1000),
                        "currentUsage": \(userId * 100),
                        "resetTime": \(Date().timeIntervalSince1970 + Double(userId * 3600)),
                        "rateLimit": {
                            "requestsPerMinute": \(userId * 10),
                            "burstLimit": \(userId * 5),
                            "windowSize": 60
                        }
                    }
                },
                "activities": [
                    \((1...5).map { activityId in
                        """
                        {
                            "id": "activity_\(userId)_\(activityId)",
                            "type": "action_\(activityId)",
                            "timestamp": \(Date().timeIntervalSince1970 - Double(activityId * 3600)),
                            "description": "User performed action \(activityId) with some detailed description",
                            "metadata": {
                                "source": "web",
                                "ipAddress": "192.168.1.\(userId % 255)",
                                "userAgent": "Mozilla/5.0 Browser Agent String",
                                "duration": \(activityId * 1000),
                                "success": \(activityId % 2 == 0)
                            },
                            "score": \(activityId * 10)
                        }
                        """
                    }.joined(separator: ","))
                ],
                "isActive": \(userId % 2 == 0),
                "lastLogin": \(Date().timeIntervalSince1970 - Double(userId * 1800)),
                "tags": [\((1...userId%5+1).map { "\"tag\($0)\"" }.joined(separator: ","))]
            }
            """
        }.joined(separator: ",")
        
        let companies = (1...20).map { companyId in
            """
            {
                "id": \(companyId),
                "name": "Company \(companyId) Inc.",
                "domain": "company\(companyId).com",
                "industry": "Industry \(companyId % 5)",
                "employees": [
                    \((1...10).map { empId in
                        """
                        {
                            "id": \(empId),
                            "name": "Employee \(empId)",
                            "position": "Position \(empId % 5)",
                            "department": "Department \(empId % 3)",
                            "salary": \(Double(empId * 10000 + 50000)),
                            "hireDate": "2020-0\(empId % 9 + 1)-\(empId % 28 + 1)",
                            "skills": [\((1...empId%5+1).map { "\"skill\($0)\"" }.joined(separator: ","))],
                            "performance": {
                                "rating": \(Double(empId % 5 + 1) + 0.5),
                                "goals": [
                                    {
                                        "title": "Goal 1 for employee \(empId)",
                                        "progress": \(Double(empId * 10 % 100) / 100.0),
                                        "deadline": "2024-12-31",
                                        "priority": "\(empId % 3 == 0 ? "high" : empId % 3 == 1 ? "medium" : "low")"
                                    }
                                ],
                                "achievements": [\((1...empId%3+1).map { "\"achievement\($0)\"" }.joined(separator: ","))],
                                "lastReview": "2024-0\(empId % 9 + 1)-01"
                            }
                        }
                        """
                    }.joined(separator: ","))
                ],
                "revenue": {
                    "annual": \(Double(companyId * 1000000)),
                    "quarterly": [\(companyId * 250000), \(companyId * 300000), \(companyId * 200000), \(companyId * 250000)],
                    "monthly": [\((1...12).map { String(companyId * 80000 + $0 * 10000) }.joined(separator: ","))],
                    "forecast": {
                        "nextQuarter": \(Double(companyId * 280000)),
                        "nextYear": \(Double(companyId * 1200000)),
                        "confidence": 0.\(companyId % 10 + 80),
                        "methodology": "ML Model v\(companyId % 3 + 1)"
                    },
                    "breakdown": {
                        "products": {
                            "product_a": \(Double(companyId * 400000)),
                            "product_b": \(Double(companyId * 350000)),
                            "product_c": \(Double(companyId * 250000))
                        },
                        "regions": {
                            "north_america": \(Double(companyId * 500000)),
                            "europe": \(Double(companyId * 300000)),
                            "asia": \(Double(companyId * 200000))
                        },
                        "channels": {
                            "online": \(Double(companyId * 600000)),
                            "retail": \(Double(companyId * 400000))
                        }
                    }
                },
                "address": {
                    "street": "\(companyId * 100) Business St",
                    "city": "Business City \(companyId)",
                    "state": "State \(companyId % 10)",
                    "country": "Country \(companyId % 5)",
                    "zipCode": "\(companyId)0000",
                    "coordinates": {
                        "latitude": \(Double(companyId) * 0.5 + 40.0),
                        "longitude": \(Double(companyId) * -0.3 - 70.0),
                        "elevation": \(Double(companyId * 10))
                    }
                },
                "contacts": [
                    {
                        "name": "Contact Person \(companyId)",
                        "email": "contact\(companyId)@company\(companyId).com",
                        "phone": "+1-555-\(String(format: "%04d", companyId))",
                        "role": "Sales Manager",
                        "department": "Sales",
                        "availability": {
                            "timezone": "UTC-\(companyId % 12)",
                            "workingHours": {
                                "start": "09:00",
                                "end": "17:00",
                                "days": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"],
                                "holidays": ["2024-12-25", "2024-01-01"]
                            },
                            "preferredMethod": "\(companyId % 2 == 0 ? "email" : "phone")"
                        }
                    }
                ],
                "founded": \(1990 + companyId),
                "isPublic": \(companyId % 3 == 0)
            }
            """
        }.joined(separator: ",")
        
        return """
        {
            "status": "success",
            "code": 200,
            "message": "Data retrieved successfully",
            "timestamp": \(Date().timeIntervalSince1970),
            "data": {
                "users": [\(users)],
                "companies": [\(companies)],
                "stats": {
                    "totalUsers": 50,
                    "activeUsers": 25,
                    "newUsers": 5,
                    "churnRate": 0.15,
                    "engagement": {
                        "dailyActive": 20,
                        "weeklyActive": 35,
                        "monthlyActive": 45,
                        "averageSessionDuration": 1800.5,
                        "pageViews": 150000,
                        "bounceRate": 0.25
                    },
                    "performance": {
                        "responseTime": 125.5,
                        "uptime": 99.95,
                        "errorRate": 0.02,
                        "throughput": 1000.0,
                        "cacheHitRate": 0.85
                    },
                    "geography": {
                        "countries": {
                            "US": 25,
                            "UK": 10,
                            "CA": 8,
                            "DE": 5,
                            "FR": 2
                        },
                        "cities": {
                            "New York": 15,
                            "London": 8,
                            "Toronto": 6,
                            "Berlin": 4,
                            "Paris": 2
                        },
                        "continents": {
                            "North America": 33,
                            "Europe": 15,
                            "Asia": 2
                        }
                    }
                }
            },
            "pagination": {
                "page": 1,
                "limit": 50,
                "total": 50,
                "hasNext": false,
                "hasPrev": false,
                "totalPages": 1
            },
            "metadata": {
                "version": "1.0.0",
                "requestId": "req_12345",
                "processingTime": "150ms",
                "source": "api_v2",
                "environment": "production"
            }
        }
        """
    }
    
    // MARK: - 性能对比测试
    
    func testComplexJSONDecodingPerformance() throws {
        let jsonString = generateComplexJSON()
        let jsonData = jsonString.data(using: .utf8)!
        
        print("JSON size: \(jsonData.count) bytes (\(jsonData.count / 1024) KB)")
        
        let reerDecoder = ReerJSONDecoder()
        let foundationDecoder = JSONDecoder()
        
        // 预热
        _ = try foundationDecoder.decode(APIResponse.self, from: jsonData)
        _ = try reerDecoder.decode(APIResponse.self, from: jsonData)
        
        var reerTimes: [TimeInterval] = []
        var foundationTimes: [TimeInterval] = []
        
        let iterations = 100
        
        
        // 测试 Foundation JSON 性能
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try foundationDecoder.decode(APIResponse.self, from: jsonData)
            let endTime = CFAbsoluteTimeGetCurrent()
            foundationTimes.append(endTime - startTime)
        }
        
        // 测试 ReerJSON 性能
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            _ = try reerDecoder.decode(APIResponse.self, from: jsonData)
            let endTime = CFAbsoluteTimeGetCurrent()
            reerTimes.append(endTime - startTime)
        }
        
        let reerAverage = reerTimes.reduce(0, +) / Double(reerTimes.count)
        let foundationAverage = foundationTimes.reduce(0, +) / Double(foundationTimes.count)
        
        let reerMin = reerTimes.min()!
        let reerMax = reerTimes.max()!
        let foundationMin = foundationTimes.min()!
        let foundationMax = foundationTimes.max()!
        
        print("\n=== 复杂 JSON 解码性能对比 ===")
        print("迭代次数: \(iterations)")
        print()
        print("ReerJSON 解码器:")
        print("  平均时间: \(String(format: "%.4f", reerAverage * 1000)) ms")
        print("  最快时间: \(String(format: "%.4f", reerMin * 1000)) ms")
        print("  最慢时间: \(String(format: "%.4f", reerMax * 1000)) ms")
        print()
        print("Foundation JSON 解码器:")
        print("  平均时间: \(String(format: "%.4f", foundationAverage * 1000)) ms")
        print("  最快时间: \(String(format: "%.4f", foundationMin * 1000)) ms")
        print("  最慢时间: \(String(format: "%.4f", foundationMax * 1000)) ms")
        print()
        
        let speedRatio = foundationAverage / reerAverage
        if speedRatio > 1 {
            print("ReerJSON 比 Foundation 快 \(String(format: "%.2f", speedRatio))倍")
        } else {
            print("ReerJSON 比 Foundation 慢 \(String(format: "%.2f", 1/speedRatio))倍")
        }
        
        // 验证结果正确性
        let reerResult = try reerDecoder.decode(APIResponse.self, from: jsonData)
        let foundationResult = try foundationDecoder.decode(APIResponse.self, from: jsonData)
        
        XCTAssertEqual(reerResult.status, foundationResult.status)
        XCTAssertEqual(reerResult.data.users.count, foundationResult.data.users.count)
        XCTAssertEqual(reerResult.data.companies.count, foundationResult.data.companies.count)
        XCTAssertEqual(reerResult.data.users.first?.username, foundationResult.data.users.first?.username)
        XCTAssertEqual(reerResult.data.companies.first?.name, foundationResult.data.companies.first?.name)
        
        print("\n✅ 解码结果验证通过")
    }
    
    // MARK: - 内存使用对比
    
    func testMemoryUsageComparison() throws {
        let jsonString = generateComplexJSON()
        let jsonData = jsonString.data(using: .utf8)!
        
        let reerDecoder = ReerJSONDecoder()
        let foundationDecoder = JSONDecoder()
        
        // 测试内存使用情况
        autoreleasepool {
            measure {
                for _ in 0..<50 {
                    _ = try! reerDecoder.decode(APIResponse.self, from: jsonData)
                }
            }
        }
        
        print("ReerJSON 内存测试完成")
    }
    
    // MARK: - 数据完整性验证
    
    func testDataIntegrityValidation() throws {
        let jsonString = generateComplexJSON()
        let jsonData = jsonString.data(using: .utf8)!
        
        let reerDecoder = ReerJSONDecoder()
        let foundationDecoder = JSONDecoder()
        
        let reerResult = try reerDecoder.decode(APIResponse.self, from: jsonData)
        let foundationResult = try foundationDecoder.decode(APIResponse.self, from: jsonData)
        
        // 深度验证数据完整性
        XCTAssertEqual(reerResult.status, foundationResult.status)
        XCTAssertEqual(reerResult.code, foundationResult.code)
        XCTAssertEqual(reerResult.message, foundationResult.message)
        XCTAssertEqual(reerResult.timestamp, foundationResult.timestamp, accuracy: 0.001)
        
        // 验证用户数据
        XCTAssertEqual(reerResult.data.users.count, foundationResult.data.users.count)
        for (reerUser, foundationUser) in zip(reerResult.data.users, foundationResult.data.users) {
            XCTAssertEqual(reerUser.id, foundationUser.id)
            XCTAssertEqual(reerUser.username, foundationUser.username)
            XCTAssertEqual(reerUser.email, foundationUser.email)
            XCTAssertEqual(reerUser.isActive, foundationUser.isActive)
            XCTAssertEqual(reerUser.activities.count, foundationUser.activities.count)
            XCTAssertEqual(reerUser.profile.socialLinks.count, foundationUser.profile.socialLinks.count)
        }
        
        // 验证公司数据
        XCTAssertEqual(reerResult.data.companies.count, foundationResult.data.companies.count)
        for (reerCompany, foundationCompany) in zip(reerResult.data.companies, foundationResult.data.companies) {
            XCTAssertEqual(reerCompany.id, foundationCompany.id)
            XCTAssertEqual(reerCompany.name, foundationCompany.name)
            XCTAssertEqual(reerCompany.employees.count, foundationCompany.employees.count)
            XCTAssertEqual(reerCompany.revenue.annual, foundationCompany.revenue.annual, accuracy: 0.01)
        }
        
        // 验证统计数据
        let reerStats = reerResult.data.stats
        let foundationStats = foundationResult.data.stats
        XCTAssertEqual(reerStats.totalUsers, foundationStats.totalUsers)
        XCTAssertEqual(reerStats.engagement.dailyActive, foundationStats.engagement.dailyActive)
        XCTAssertEqual(reerStats.performance.responseTime, foundationStats.performance.responseTime, accuracy: 0.01)
        
        print("✅ 数据完整性验证通过 - 所有字段都正确解码")
    }
}
