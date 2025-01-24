using log4net;
using log4net.Config;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Protocol
{
    public class Process
    {
        private static readonly ILog logger = LogManager.GetLogger(typeof(Process));
        public Process()
        {
            XmlConfigurator.Configure(new System.IO.FileInfo("log4net.config"));
        }
        public static decimal? FetchAnalyzerValue(Models.Analyzer analyzer,Models.Channel channel)
        {
            decimal? value = null;
            logger.Info($"Fetching value for : {analyzer.ProtocolType}");
            logger.Info($"Checking if the protocol exists");
            if (Mapper.ProtocolDictionary.TryGetValue(analyzer.ProtocolType, out var method))
            {
                logger.Info("Protocol found");
                logger.Info("")
                // Call the method and capture the result
                value = method(analyzer,channel);
            }
            else
            {
                
            }
            return value;
        }
    }
}
