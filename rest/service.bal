import ballerina/io;
import ballerina/sql;
import ballerinax/java.jdbc;
import ballerinax/mysql;
import ballerinax/mysql.driver as _;
import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerina/jwt;
import ballerina/mime;

configurable string password = "rootroot";
configurable string host = "localhost";
configurable int port = 3306;
configurable string username = "root";
string db = "defaultdb";


type Item record {
    string ID;
    string Title;
    string Description;
    string Includes;
    string IntendedFor;
    string Color;
    string Material;
    float Price;
    string sellerId;
};

type Department record {
    string id;
    string name;
    string location;
    string manager;
};

type DeliveryStatusItem record {
    int id;
    string itemList;
    string total;
    PurchaseItem[] purchaseItems;
};

type PurchaseItem record {
    string name;
    int quantity;
    float unitPrice;
    float total;
    int delivered;
    int purchaseId;
    int itemId;
};


type InsertExecutionResult record {
    int affectedRowCount;
    int lastInsertId;
};

type ErrorRecord record {|
    *http:InternalServerError;
    record {
        string message;
    } body;
|};

// @http:ServiceConfig {
//     cors: {
//         allowOrigins: ["http://localhost:3000"],
//         allowCredentials: false,
//         allowHeaders: ["CORELATION_ID"],
//         exposeHeaders: ["X-CUSTOM-HEADER"],
//         maxAge: 84900
//     }
// }
service /ecom/rest on new http:Listener(9091) {

    private final mysql:Client dbClient;

    function init() returns error? {
        log:printInfo("Cake API started", host = "0.0.0.0", port = 9091, protocol = "HTTP");
        mysql:Options mysqlOptions = {
            ssl: {
                mode: mysql:SSL_PREFERRED
            },
            connectTimeout: 10
        };
        do {
            self.dbClient = check new (host = host, user = username, password = password, database = db, port = port, connectionPool = {maxOpenConnections: 3});
        } on fail var e {
            log:printError("Error occurred while connecting to MySQL", e);
            return e;
        }
        log:printInfo("Connected to database !");
    }

    resource function get menu(@http:Header string Connection) returns json|http:Ok|http:InternalServerError|error {
        io:println("Printing headers !!");
        io:println(Connection);
        json response = {"Butter Cake": 15, "Chocolate Cake": 20, "Tres Leches": 25};
        http:Ok ok = {body: response};
        return ok;
    }

    function decode(string value) returns ()|string {
        string|byte[]|io:ReadableByteChannel|mime:DecodeError decodedJWT = mime:base64Decode(value, charset = "utf-8");
        if (decodedJWT is string) {
            return decodedJWT;
        }
        return null;
    }

    public function decodeAndAssert(string rawJWT) returns ()|string{
        string[] split_string = regex:split(rawJWT, "\\.");
        string base64EncodedHeader = split_string[0]; // Header part
        string base64EncodedBody = split_string[1]; // Payload part
        string base64EncodedSignature = split_string[2]; // Signature
        string? decodedHeader = self.decode(base64EncodedHeader);
        string? decodedBody =  self.decode(base64EncodedBody);
        io:println("header: ");
        io:println(decodedHeader);
        io:println("body");
        io:println(decodedBody);
    }

    resource function get items(http:Headers headers, string sellerId) returns Item[]|ErrorRecord {
        io:println("items() called: ");
        io:println("Printing headers !!");
        // io:println(headers.getHeaders("X-JWT-Assertion"));
        string[]|error jwtArray = headers.getHeaders("X-JWT-Assertion");
        string[] headerNames = headers.getHeaderNames();
        io:println(headerNames);
        string[]|error usernameid = headers.getHeaders("usernameid");
        io:println(usernameid);
        if (jwtArray is string[]) {
            string jwt = jwtArray[0];
            // io:println(jwt);
            jwt:ValidatorConfig validatorConfig = {
                issuer: "wso2.org/products/am",
                // audience: "EtKG7RgMr9Q_TFmWOxrdan1toVIa",
                clockSkew: 60,
                signatureConfig: {
                    certFile: "/Users/ramindu/wso2/general_demo/APIM-IS/wso2carbon.cer"
                }
            };
            do {
	            jwt:Payload result = check jwt:validate(jwt, validatorConfig);
                io:println("printing JWT related Info !!");
                io:println(result);
                io:println("Done printing JWT related Info !!");
            } on fail var e {
            	io:println("Error occurred when validating backend jwt", e);
            }
            
        }

        var sellerIdInteger = int:fromString(sellerId);
        if (sellerIdInteger is int) {
            if (sellerIdInteger != -1) {
                return {body: { message: "Exception ocurred when reading sellerId" }};
            }
        } 
        
        Item[] items = [];
        do {
            // mysql:Client mysqlClients = check new ("sahackathon.mysql.database.azure.com", "choreo", "wso2!234", "db_name", 3306, connectionPool={maxOpenConnections: 3});
            if (self.dbClient is jdbc:Client) {
                do {
                    // sql:ExecutionResult createTableResult = check self.dbClient->execute(`SELECT * FROM itemtable`);
                    io:println("DBClient OK: ");
                    sql:ParameterizedQuery query;
                    io:println("sellerId : " + sellerId);
                    if (sellerId == "-1") {
                        query = `SELECT * from itemtable`;
                    } else {
                        query = `SELECT * from itemtable where sellerId = ${sellerId}`;
                    }
                    io:println(query);
                    stream<Item, sql:Error?> resultStream = self.dbClient->query(query);

                    check from Item item in resultStream
                        do {
                            io:println("adding item: ", item);
                            items.push(item);
                        };
                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                }
            } else {
                
                
            }
            io:println(items);
            return items;
        }
    }
    
    resource function post item(@http:Payload map<json> jsonString) returns string {
        return self.addOrEditItem(jsonString, false);
    }

    resource function put item(@http:Payload map<json> jsonString) returns string {
        return self.addOrEditItem(jsonString, true);
    }

    resource function get purchaseItems(string id) returns DeliveryStatusItem[] {
        io:println("purchaseItems() called: ");
        DeliveryStatusItem[] items = [];
        PurchaseItem[] purchaseItems = [];
        do {
            // mysql:Client mysqlClients = check new ("sahackathon.mysql.database.azure.com", "choreo", "wso2!234", "db_name", 3306, connectionPool={maxOpenConnections: 3});
            if (self.dbClient is jdbc:Client) {
                do {
                    // sql:ExecutionResult createTableResult = check self.dbClient->execute(`SELECT * FROM itemtable`);
                    // io:println("DBClient OK: ", createTableResult);
                    sql:ParameterizedQuery query = `SELECT id, itemList, total from PurchaseTable where username=${id}`;
                    stream<DeliveryStatusItem, sql:Error?> resultStream = self.dbClient->query(query);
                    check from DeliveryStatusItem item in resultStream
                        do {
                            int purchaseId = item.id;
                            query = `SELECT name, quantity, unitPrice, total, delivered from PurchaseItemTable where purchaseId=${purchaseId}`;
                            
                            stream<PurchaseItem, sql:Error?> resultStream2 = self.dbClient->query(query);
                            check from PurchaseItem purchaseItem in resultStream2
                            do {
                                purchaseItems.push(purchaseItem);
                            };
                            item.purchaseItems = purchaseItems;
                            items.push(item);
                        };
                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                }
            }
            io:println(items);
            return items;
        }
    }

    resource function get sellerDispatchItems(string sellerId) returns DeliveryStatusItem[] {
        io:println("sellerDispatchItems() called: ");
        DeliveryStatusItem[] deliveryItems = [];
        PurchaseItem[] purchaseItems = [];
        do {
            // mysql:Client mysqlClients = check new ("sahackathon.mysql.database.azure.com", "choreo", "wso2!234", "db_name", 3306, connectionPool={maxOpenConnections: 3});
            if (self.dbClient is jdbc:Client) {
                do {
                    // sql:ExecutionResult createTableResult = check self.dbClient->execute(`SELECT * FROM itemtable`);
                    // io:println("DBClient OK: ", createTableResult);
                    sql:ParameterizedQuery query = `SELECT name, quantity, unitPrice, total, delivered, purchaseId, itemId from PurchaseItemTable where sellerId=${sellerId}`;
                    stream<PurchaseItem, sql:Error?> resultStream = self.dbClient->query(query);
                    check from PurchaseItem item in resultStream
                        do {
                            boolean purchaseAvailable = false;
                            io:println(item);
                            foreach DeliveryStatusItem deliveryItem in deliveryItems {
                                if (deliveryItem.id == item.purchaseId) {
                                    purchaseAvailable = true;
                                    break;
                                }
                            }
                            // DeliveryStatusItem[] deliveryItems2 = [];
                            io:println("Purchase record available: ", purchaseAvailable);
                            if (!purchaseAvailable) {
                                sql:ParameterizedQuery query2 = `SELECT id, itemList, total from PurchaseTable where id=${item.purchaseId}`;
                                io:println("executing : SELECT id, itemList, total from PurchaseTable where username=${item.id}", item.purchaseId);
                                stream<DeliveryStatusItem, sql:Error?> resultStream2 = self.dbClient->query(query2);
                                check from DeliveryStatusItem deliveryStatus in resultStream2
                                do {
                                    io:println(deliveryStatus);
                                    deliveryStatus.purchaseItems = [];
                                    deliveryItems.push(deliveryStatus);
                                    // deliveryItems2.push(deliveryStatus);
                                };
                            }
                            foreach DeliveryStatusItem deliveryItem in deliveryItems {
                                if (deliveryItem.id == item.purchaseId) {
                                    deliveryItem.purchaseItems.push(item);
                                    break;
                                }
                            }
                        };
                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                }
            }
            io:println(deliveryItems);
            return deliveryItems;
        }
    }


    resource function post updateDeliveryStatus(@http:Payload map<json> mapJson) returns string {
        io:println("updateDeliveryStatus() called: ");
        io:println(mapJson.toJsonString());
        boolean status = <boolean>mapJson["status"];
        int itemId = <int>mapJson["itemId"];
        int purchaseId = <int>mapJson["purchaseId"];
        if (self.dbClient is jdbc:Client) {
            io:println(`UPDATE PurchaseTable (delivered) SET delivered = ${status} where id = ${purchaseId})`);
            if (self.dbClient is jdbc:Client) {
                do {
                    sql:ParameterizedQuery query = `UPDATE PurchaseItemTable SET delivered = ${status} where purchaseId = ${purchaseId} and itemId = ${itemId}`;
                    sql:ExecutionResult result = check self.dbClient->execute(query);
                    io:println("Item updated: ", result);
                    int? count = result.affectedRowCount;
                    //The integer or string generated by the database in response to a query execution.
                    string|int? generatedKey = result.lastInsertId;
                    // json jsonResultObject = <json>result;
                    // InsertExecutionResult|error insertExecutionResult = jsonResultObject.fromJsonWithType();
                    if (generatedKey is string) {
                        return generatedKey;
                    } else {
                        return generatedKey.toString();
                    }
                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                    return "Exception occurred when inserting or updating";
                }
            }
        }
    }

    resource function delete cancelPurchase(string idstring) returns string {
        io:println("purchase cancel called: ");
        int|error id = int:fromString(idstring);
        if (id is int) {
            Item[] items = [];
            do {
                // mysql:Client mysqlClients = check new ("sahackathon.mysql.database.azure.com", "choreo", "wso2!234", "db_name", 3306, connectionPool={maxOpenConnections: 3});
                if (self.dbClient is jdbc:Client) {
                    do {
                        // sql:ExecutionResult createTableResult = check self.dbClient->execute(`SELECT * FROM itemtable`);
                        // io:println("DBClient OK: ", createTableResult);
                        sql:ParameterizedQuery query = `DELETE FROM PurchaseTable WHERE id = ${id};`;
                        // sql:ExecutionResult|sql:Error resultStream = self.dbClient->execute(query);
                        sql:ExecutionResult result = check self.dbClient->execute(query);
                        io:println("result delete: ");
                        if result.affectedRowCount is int {
                            io:println("Successfully deleted the purchase");
                        } else {
                            io:println("Unable to delete the purchase");
                        }
                        query = `DELETE FROM PurchaseItemTable WHERE purchaseId = ${id};`;
                        // sql:ExecutionResult|sql:Error resultStream = self.dbClient->execute(query);
                        result = check self.dbClient->execute(query);
                        io:println("result delete: ");
                        if result.affectedRowCount is int {
                            io:println("Successfully deleted from PurchaseItemTable");
                            return "Successfully deleted the purchase";
                        } else {
                            io:println("Unable to delete from PurchaseItemTable");
                            return "Unable to delete the purchase";
                        }
                    } on fail var e {
                        return "Exception occurred when inserting. " + e.message();
                    }
                }
            }
        }
        return "Exception occurred when converting the id from query param.";
    }

    resource function post purchaseItems(@http:Payload map<json> mapJson) returns string {
        io:println(mapJson.toJsonString());
        json[] itemList = <json[]>mapJson["itemList"];
        float total = <float>mapJson["total"];
        float subtotal = <float>mapJson["subtotal"];
        float shipping = <float>mapJson["shipping"];
        float tax = <float>mapJson["tax"];
        string fullName = <string>mapJson["fullName"];
        string username = <string>mapJson["username"];
        string expirationdate = <string>mapJson["expirationdate"];
        int cardnumber = <int>mapJson["cardnumber"];
        int cvv = <int>mapJson["cvv"];
        if (self.dbClient is jdbc:Client) {
            io:println(`INSERT INTO PurchaseTable (itemList, total, subtotal, shipping, tax, fullName, expirationdate, cardnumber, cvv) VALUES ${itemList}, ${total}, ${fullName}, ${cardnumber})`);
            if (self.dbClient is jdbc:Client) {
                do {
                    sql:ParameterizedQuery query = `INSERT INTO PurchaseTable (itemList, total, subtotal, shipping, tax, fullName, expirationdate, cardnumber, cvv, username) 
                        VALUES (${itemList.toJsonString()}, ${total}, ${subtotal}, ${shipping}, ${tax}, ${fullName}, ${expirationdate}, ${cardnumber}, ${cvv}, ${username})`;
                    sql:ExecutionResult result = check self.dbClient->execute(query);
                    io:println("Purchase inserted: ", result);
                    int? count = result.affectedRowCount;
                    //The integer or string generated by the database in response to a query execution.
                    string|int? generatedKey = result.lastInsertId;
                    // json jsonResultObject = <json>result;
                    // InsertExecutionResult|error insertExecutionResult = jsonResultObject.fromJsonWithType();
                    foreach json item in itemList {
                        string sellerId;
                        map<json> jsonItem = <map<json>>item;
                        int itemId = <int>jsonItem["id"];
                        io:println(jsonItem);
                        sql:ParameterizedQuery selectSellerIdQuery;
                        selectSellerIdQuery = `SELECT sellerId from itemtable where id = ${itemId}`;
                        stream<Item, sql:Error?> resultStream = self.dbClient->query(selectSellerIdQuery);
                        check from Item tempItem in resultStream
                        do {
                            sellerId = tempItem.sellerId;
                        };
                        sql:ParameterizedQuery query2 = `INSERT INTO PurchaseItemTable (purchaseId, name, quantity, unitPrice, total, sellerId, delivered, itemId) 
                            VALUES (${generatedKey}, ${<string>jsonItem["name"]}, ${<int>jsonItem["quantity"]}, ${<float>jsonItem["unitPrice"]}, ${<float>jsonItem["total"]}, ${sellerId}, false, ${itemId})`;
                        sql:ExecutionResult result2 = check self.dbClient->execute(query2);
                        io:println("Item inserted for purchase id: ", generatedKey);
                    }
                    if (generatedKey is string) {
                        return generatedKey;
                    } else {
                        return generatedKey.toString();
                    }
                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                    return "Exception occurred when inserting or updating";
                }
            }
        }
    }

    function addOrEditItem(map<json> mapJson, boolean isPut) returns string {
        int|error id = -1;
        if (isPut) {
            id = int:fromString(<string>mapJson["id"]);
            if (id is error) {
                return "the is not defined to update the product";
            }
            // id = <int>mapJson["id"];
        }
        string title = <string>mapJson["title"];
        string description = <string>mapJson["description"];
        string intendedFor = <string>mapJson["intendedFor"];
        string includes = <string>mapJson["includes"];
        string color = <string>mapJson["color"];
        string material = <string>mapJson["material"];
        float price = <float>mapJson["price"];

        // jdbc:Client|sql:Error dbClient = new (hostPortDB, username, password, poolOptions: {maximumPoolSize: 5});
        io:println("DB Client initiated");
        if (self.dbClient is jdbc:Client) {
            io:println("DB Client created successfully");
            io:println(mapJson.toString());
            io:println(`INSERT INTO itemtable (title, description, includes, intendedFor, color, material, price) VALUES ${title}, ${description}, ${includes}, ${intendedFor}, ${color}, ${material}, ${price})`);
            if (self.dbClient is jdbc:Client) {
                do {
                    if (id == -1 && price is float) {
                        string sellerId = <string>mapJson["sellerId"];
                        sql:ParameterizedQuery query = `INSERT INTO itemtable (title, description, includes, intendedFor, color, material, price, sellerId) 
                                VALUES (${title}, ${description}, ${includes}, ${intendedFor}, ${color}, ${material}, ${price}, ${sellerId})`;
                        sql:ExecutionResult result = check self.dbClient->execute(query);
                        io:println("Item inserted: ", result);
                        int? count = result.affectedRowCount;
                        //The integer or string generated by the database in response to a query execution.
                        string|int? generatedKey = result.lastInsertId;
                        // json jsonResultObject = <json>result;
                        // InsertExecutionResult|error insertExecutionResult = jsonResultObject.fromJsonWithType();
                        if (generatedKey is string) {
                            return generatedKey;
                        } else {
                            return generatedKey.toString();
                        }

                    } else if (id is int && price is float) {
                        sql:ParameterizedQuery query = `UPDATE itemtable SET title = ${title}, description = ${description}, 
                                includes = ${includes}, intendedFor = ${intendedFor}, color = ${color}, material = ${material}, price = ${price}
                                 WHERE ID = ${id};`;
                        sql:ExecutionResult result = check self.dbClient->execute(query);
                        io:println("Item updated: ", result);
                        int? count = result.affectedRowCount;
                        //The integer or string generated by the database in response to a query execution.
                        string|int? generatedKey = result.lastInsertId;
                        // json jsonResultObject = <json>result;
                        // InsertExecutionResult|error insertExecutionResult = jsonResultObject.fromJsonWithType();
                        if (generatedKey is string) {
                            return generatedKey;
                        } else {
                            return generatedKey.toString();
                        }
                    }

                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                    return "Exception occurred when inserting or updating";
                }
            }
        }

        // Item item = {Title: "entry.Title", Description: "entry.Description", Includes: "entry.Includes", IntendedFor: "entry.IntendedFor", Color: "entry.Color", Material: "entry.Material", Price: 12.23};
        // return new ItemData(item);
        return "execption ocurrec when updating or adding the product";
    }

    resource function delete item(string idstring) returns string {
        io:println("items delete called: ");
        int|error id = int:fromString(idstring);
        if (id is int) {
            Item[] items = [];
            do {
                // mysql:Client mysqlClients = check new ("sahackathon.mysql.database.azure.com", "choreo", "wso2!234", "db_name", 3306, connectionPool={maxOpenConnections: 3});
                if (self.dbClient is jdbc:Client) {
                    do {
                        // sql:ExecutionResult createTableResult = check self.dbClient->execute(`SELECT * FROM itemtable`);
                        // io:println("DBClient OK: ", createTableResult);
                        sql:ParameterizedQuery query = `DELETE FROM itemtable WHERE id = ${id};`;
                        sql:ExecutionResult|sql:Error resultStream = self.dbClient->execute(query);
                        if (resultStream is sql:ExecutionResult) {
                            int? affectedRowCount = resultStream.affectedRowCount;
                            if affectedRowCount is int {
                                return "Successfully deleted the item";
                            } else {
                                return "Unable to delete the item";
                            }
                        }
                    } on fail var e {
                        return "Exception occurred when inserting. " + e.message();
                    }
                }
                return "Exception occurred when deleting.";
            }
        }
        return "Exception occurred when converting the id from query param.";
    }

    resource function get item(int itemId) returns Item|ErrorRecord {
        io:println("item() called: ");
        
        Item item = {Includes: "", IntendedFor: "", Description: "", sellerId: "", Price: 0.0, Color: "", Title: "", Material: "", ID: ""};
        do {
            // mysql:Client mysqlClients = check new ("sahackathon.mysql.database.azure.com", "choreo", "wso2!234", "db_name", 3306, connectionPool={maxOpenConnections: 3});
            if (self.dbClient is jdbc:Client) {
                do {
                    // sql:ExecutionResult createTableResult = check self.dbClient->execute(`SELECT * FROM itemtable`);
                    io:println("DBClient OK: ");
                    sql:ParameterizedQuery query;
                    io:println(itemId);
                    query = `SELECT * from itemtable where id = ${itemId}`;
                    io:println(query);
                    stream<Item, sql:Error?> resultStream = self.dbClient->query(query);

                    check from Item tempItem in resultStream
                        do {
                            item = tempItem;
                        };
                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                }
            } 
            io:println(item);
            return item;
        }
    }

    resource function get department(string departmentName) returns Department|ErrorRecord {
        io:println("item() called: ");
        
        Department department = {manager: "", name: "", location: "", id: ""};
        do {
            // mysql:Client mysqlClients = check new ("sahackathon.mysql.database.azure.com", "choreo", "wso2!234", "db_name", 3306, connectionPool={maxOpenConnections: 3});
            if (self.dbClient is jdbc:Client) {
                do {
                    // sql:ExecutionResult createTableResult = check self.dbClient->execute(`SELECT * FROM itemtable`);
                    io:println("DBClient OK: ");
                    sql:ParameterizedQuery query;
                    io:println(departmentName);
                    query = `SELECT * from departmentTable where name = ${departmentName}`;
                    io:println(query);
                    stream<Department, sql:Error?> resultStream = self.dbClient->query(query);

                    check from Department tempDepartment in resultStream
                        do {
                            department = tempDepartment;
                        };
                } on fail var e {
                    io:println("Exception occurred when inserting. ", e);
                }
            } 
            io:println(department);
            return department;
        }
    }
}
