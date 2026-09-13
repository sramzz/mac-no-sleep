import Foundation

let helper = HelperService()
let listener = NSXPCListener(machServiceName: HelperService.machServiceName)
listener.delegate = helper
listener.resume()

RunLoop.main.run()
