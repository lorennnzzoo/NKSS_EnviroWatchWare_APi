using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IPCBService
    {
        void CreateCPCBStationConfig(Models.PCB.CPCB.StationConfiguration stationConfiguration);
        void CreateCPCBChannelConfig(Models.PCB.CPCB.ChannelConfiguration channelConfiguration);

        IEnumerable<Models.PCB.CPCB.StationConfiguration> GetCPCBStationsConfigs();
        IEnumerable<Models.PCB.CPCB.ChannelConfiguration> GetCPCBChannelsConfigsByStationId(int stationId);
    }
}
