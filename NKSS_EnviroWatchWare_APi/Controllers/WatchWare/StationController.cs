using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("Station")]
    public class StationController : ApiController
    {
        private readonly StationService station_service;
        private Helpers.Validator validator = new Helpers.Validator();
        public StationController(StationService _station_service)
        {
            this.station_service = _station_service;
        }

        [Authorize(Roles = "Admin")]
        [HttpGet]
        [Route("GetStation")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var station = station_service.GetStationById(id);
                if (station == null)
                    return NotFound();
                return Ok(station);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [Authorize(Roles = "Admin,Customer")]
        [HttpGet]
        [Route("GetAllStations")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var stations = station_service.GetAllStations();
                return Ok(stations);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpGet]
        [Route("GetAllStationsByCompany")]
        public IHttpActionResult GetAllByCompany(int companyId)
        {
            try
            {
                var stations = station_service.GetAllStationsByCompanyId(companyId);
                return Ok(stations);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpPost]
        [Route("AddStation")]
        public IHttpActionResult Add(Post.Station station)
        {
            try
            {
                //if (station == null)
                //    return BadRequest("Invalid data.");
                var result = validator.ValidateProperties(station);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                station_service.CreateStation(station);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpPut]
        [Route("UpdateStation")]
        public IHttpActionResult Update(Models.Put.Station station)
        {
            try
            {
                //if (station == null)
                //    return BadRequest("Invalid data.");
                var result = validator.ValidateProperties(station);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                station_service.UpdateStation(station);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [Authorize(Roles = "Admin")]
        [HttpDelete]
        [Route("DeleteStation")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                station_service.DeleteStation(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }
    }
}
