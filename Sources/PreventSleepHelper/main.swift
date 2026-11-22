import Foundation

let helper = HelperService(idleTimeoutSeconds: 15.0)
let listener = NSXPCListener(machServiceName: HelperService.machServiceName)
listener.delegate = helper
listener.resume()

RunLoop.main.run()
