using Models;
using Protocol.Interfaces;
using Protocol.RS485;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Protocol
{
    public class Methods
    {

        private static decimal? ProcessProtocolData(IProtocol protocol, Analyzer analyzer,Channel channel)
        {
            decimal? value = null;
            try
            {
                string data = GetExternalData(protocol, analyzer, channel);

                if (!string.IsNullOrEmpty(data))
                {
                    value = protocol.GetDataFromResponse(data, channel);
                }
                else
                {
                    //null response
                }
            }
            catch (Exception ex)
            {
                
            }
            return value;
        }
        private static string GetExternalData(IProtocol protocol, Analyzer analyzer,Channel channel)
        {
            string data = string.Empty;
            data = protocol.ConnectToModuleAndGetResponse(analyzer);            
            return data;
        }
       
        public static decimal? GetDataFromRS485Integer(Analyzer analyzer,Channel channel)
        {
            INTEGER protocol = new INTEGER();
            return ProcessProtocolData(protocol, analyzer, channel);
        }
    }
}
