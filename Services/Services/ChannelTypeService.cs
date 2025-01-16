using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;

namespace Services
{
    public class ChannelTypeService : IChannelTypeService
    {
        private readonly IChannelTypeRepository _channelTypeRepository;
        public ChannelTypeService(IChannelTypeRepository channelTypeRepository)
        {
            _channelTypeRepository = channelTypeRepository;
        }
        public void CreateChannelType(Post.ChannelType channelType)
        {
            _channelTypeRepository.Add(channelType);
        }

        public void DeleteChannelType(int id)
        {
            _channelTypeRepository.Delete(id);
        }

        public IEnumerable<Models.ChannelType> GetAllChannelTypes()
        {
            return _channelTypeRepository.GetAll();
        }

        public Models.ChannelType GetChannelTypeById(int id)
        {
            return _channelTypeRepository.GetById(id);
        }

        public void UpdateChannelType(Models.ChannelType channelType)
        {
            _channelTypeRepository.Update(channelType);
        }
    }
}
