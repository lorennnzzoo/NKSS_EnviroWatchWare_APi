using Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Protocol.Interfaces
{
    public interface IProtocol
    {
        string ConnectToModuleAndGetResponse(Analyzer analyzer);
        decimal? GetDataFromResponse(string response,Channel channel);
        byte[] HexStringToByteArray(string s);
        string ByteArrayToHexString(byte[] data);
        string SerialPortWriteAndReceiveResponse(string command, string comport, int baudrate);
        string TCP_IPWriteAndReceiveResponse(string command, string ip, string comport);
        string UDP_IPWriteAndReceiveResponse(string command, string ip, string comport);
        decimal? ProcessResponseString(string response, Models.Channel channel);
    }
}
