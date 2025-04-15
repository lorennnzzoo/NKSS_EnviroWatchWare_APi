using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Models.PCB.CPCB
{    
    public class StationConfiguration
    {
        public Guid Id { get; set; }
        public int StationId { get; set; }
        public string StationName { get; set; }
        public string CPCB_StationId { get; set; }
        public string CPCB_UserName { get; set; }
        public string CPCB_Password { get; set; }
    }

    public class ChannelConfiguration
    {
        public Guid Id { get; set; }
        public int ChannelId { get; set; }
        public string ChannelName { get; set; }
        public int StationId { get; set; }
        public int CPCB_ChannelId { get; set; }
        public string CPCB_ChannelName { get; set; }
        public string CPCB_Units { get; set; }
    }
}
