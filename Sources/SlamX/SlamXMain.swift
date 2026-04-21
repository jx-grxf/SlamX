import Foundation

@main
enum SlamXMain {
    static func main() {
        if CommandLine.arguments.contains("--sensor-helper") {
            SensorHelperCommand.run(arguments: CommandLine.arguments)
            return
        }

        SlamXApp.main()
    }
}
