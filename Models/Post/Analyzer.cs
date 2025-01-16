using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.Post
{
    public class Analyzer
    {        
        public string ProtocolType { get; set; }
        public string CommunicationType { get; set; }
        public string Command { get; set; }
        public string ComPort { get; set; }
        public int? BaudRate { get; set; }
        public string Parity { get; set; }
        public int? DataBits { get; set; }
        public string StopBits { get; set; }
        public string IpAddress { get; set; }
        public int? Port { get; set; }
        public string Manufacturer { get; set; }
        public string Model { get; set; }
        public bool Active { get; set; } = true;
    }

}
