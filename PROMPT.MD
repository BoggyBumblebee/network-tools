Prompt for Network Tools

I’ll build a “Network Tools” application that will be a macOS SwiftUI project that will have an unified interface with multiple tabs that provide the following functionality:

- Tab 1: Info (the application should always open on this tab - it is the default tab)
    - This tab will provide information for each network interface on the macOS device.  The network interface will be selectable via a Picker
    - There will be panels below the Picker that provide details when a network interface has been selected:
        - The left panel - "Interface Information", which will contain the following information from the network interface:
            - Hardware Address
            - IP Address
            - Link Speed
            - Transport Speed
            - Link Status
            - Vendor
            - Model
        - The right panel - "Transfer Statistics", which will contain the following information from the network interface:
            - Sent Packages
            - Sent Data
            - Send Errors
            - Received Packages
            - Received Data
            - Received Errors
            - Collisions
        - On selection of a different network interface from the Picker, these panels will be updated with information from the selected network interface,
        - This will be updated every 15 seconds, and the Ui refreshed when the user is on the tab.  When the user is not on this tab, it does not need to be refreshed.
- Tab 2: Ping
    - This tab will allow the user to ping an IPv4 IP Address or an Internet Hostname (www.example.com) either for a fixed set of pings, which can be provide in the UI by the user, or for an unlimited amount of pings. 
        - The user can enter the IP Address or Internet Hostname into a Text Box,.
            - The UI should validate the IP Address or the Internet Hostname are valid before starting the ping
                - If the input is invalid, the 'Ping' Button should be disabled until a valid input is inputted
        - They can enter the number of pings into a text box labelled '# Pings to send' or select a Radio Button labelled 'Send an unlimited number of pings'.  
            - The UI should validate the input is numeric and less than  100
                - If the input is invalid, the 'Ping' Button should be disabled until a valid input is inputted
        - They can then press a 'Ping' Button to start the ping process.
            - When the 'Ping' button has been pressed its text will change to 'Stop'. 
            - If the user presses the button when its text is 'Stop', the ping function will stop and the Button's text will revert to 'Ping'. 
            - The results of the ping will then be displayed to the user in the UI in a large Text Box.
                - This Text Box should have the ability to have its contents copied.
        - If the user moves to another tab the ping should continue
- Tab 3: Port Scan
    - This tab will allow the user to port scan an IPv4 IP Address or an Internet Hostname (www.example.com) either for all ports (1 to 65535) or for a subset that can be specified by the user in two text boxes ('from' and 'To').
        - The user can enter the IP Address or Internet Hostname into a Text Box,.
            - The UI should validate the IP Address or the Internet Hostname are valid before starting the ping
                - If the input is invalid, the 'Scan' Button should be disabled until a valid input is inputted
        - The user can enter a range (from 1 to 65535) in two text boxes (labelled 'from' and 'To').
            - The UI should validate that both inputs are numeric and within the range of 1 to 65535
                - If the input is invalid, the 'Scan' Button should be disabled until a valid input is inputted
        - They can then press a 'Scan' Button to start the ping process.
            - When the 'Scan' button has been pressed its text will change to 'Stop'. 
            - If the user presses the button when its text is 'Stop', the ping function will stop and the Button's text will revert to 'Scan'. 
            - The results of the post scan will then be displayed to the user in the UI in a large Text Box.
                - This Text Box should have the ability to have its contents copied.
        - If the user moves to another tab the port scan should continue

There is no requirement to store data for this application, it will stateless.
 
We do not require iPhone or iPad support.

Based on my instructions, I want you to generate a markdown version of a  SPEC file (named SPEC.MD)for me which I can hand off to my colleagues to build this app.  

Is there any additional information you need to do that?
